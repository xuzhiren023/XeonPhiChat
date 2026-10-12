"""Mapping accounting against Linux smaps; no KNC or model inference required."""
from pathlib import Path
import mmap
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[1]


def parse_smaps(text: str, path: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(['awk', '-v', f'path={path}', '-f',
                           str(ROOT / 'scripts/model-map.awk')],
                          input=text, text=True, capture_output=True, check=False)


def test_model_mapping_is_counted_once_with_real_shared_pages(tmp_path: Path) -> None:
    model = tmp_path / 'fixture.gguf'
    model.write_bytes(b'x' * (8 * 1024 * 1024))
    with model.open('rb') as f, mmap.mmap(f.fileno(), 0, flags=mmap.MAP_SHARED,
                                        prot=mmap.PROT_READ) as region:
        # Fault in the actual file pages; this is an opaque byte fixture, not a model.
        assert sum(region[i] for i in range(0, len(region), 4096)) > 0
        result = parse_smaps(Path('/proc/self/smaps').read_text(), str(model))
        assert result.returncode == 0
        size, resident, total, unsafe = map(int, result.stdout.split())
        assert size == 8192 and resident >= 8192 and total >= resident and unsafe == 0
        additional = total - resident
        assert additional + resident == total


@pytest.mark.parametrize('perms,unsafe', [('r--s', 0), ('rw-s', 1), ('r--p', 1)])
def test_only_read_only_shared_model_pages_receive_credit(perms: str, unsafe: int) -> None:
    result = parse_smaps(f'1000-2000 {perms} 00000000 00:01 1 /fixture.gguf\n'
                         'Size: 1024 kB\nRss: 768 kB\n'
                         '2000-3000 rw-p 00000000 00:00 0 [heap]\n'
                         'Size: 2048 kB\nRss: 512 kB\n', '/fixture.gguf')
    size, resident, total, rejected = map(int, result.stdout.split())
    assert total == 1280 and rejected == unsafe
    assert (size, resident) == ((1024, 768) if not unsafe else (0, 0))


def test_unrelated_and_missing_mapping_telemetry() -> None:
    result = parse_smaps('1000-2000 r--s 0 00:01 1 /other.gguf\nSize: 1024 kB\nRss: 768 kB\n', '/fixture.gguf')
    assert list(map(int, result.stdout.split())) == [0, 0, 768, 0]
    assert parse_smaps('', '/fixture.gguf').returncode != 0
