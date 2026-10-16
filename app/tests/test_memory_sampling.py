"""Exercise the actual shell sampler with changing proc snapshots; no card."""
from pathlib import Path
import os
import shutil
import subprocess

import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def check_memory_snapshot_refresh(tmp_path, worker, mode, ok, reason):
    bash = os.environ.get('PHICHAT_TEST_BASH') or shutil.which('bash')
    assert bash, 'Bash is required for shell worker development tests'
    text = (ROOT/'scripts'/worker).read_text()
    functions = text.split('# BEGIN MODEL MEMORY SAMPLER\n')[1].split('# END MODEL MEMORY SAMPLER')[0]
    budget_check = next(line for line in text.splitlines() if line.strip().startswith('((additional_rss <= RUNTIME_LIMIT_MIB'))
    (tmp_path/'report').mkdir()
    prelude = r'''
set -euo pipefail
job=.; model_pid=123; MODEL_PATH=/fixture.gguf
MODEL_BYTES=1073741824; RUNTIME_LIMIT_MIB=300; MEMORY_STOP_MIB=256
fail() { echo "$*" >&2; exit 1; }
read_memory() { available=500000; [[ $MODE != low ]] || available=1024; }
awk() {
    if [[ ${*: -1} == */smaps ]]; then
        n=$(cat count 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > count
        if [[ $MODE == unsafe ]]; then echo '1048576 1048576 1200000 1'
        elif ((n == 1)) || [[ $MODE == copy ]]; then echo '0 0 50000 0'
        else echo '1048576 1048576 1200000 0'; fi
    else echo '1200000 1200000'; fi
}
'''
    command = prelude + functions + '\nphi_sample_model_memory\n' + budget_check + '\necho "$additional_rss"\n'
    result = subprocess.run([bash, '-c', command], cwd=tmp_path,
                            env=dict(os.environ, MODE=mode), text=True, capture_output=True)
    assert (result.returncode == 0) == ok, result.stderr
    if ok:
        assert result.stdout.strip() == '151424'
        assert (tmp_path/'count').read_text().strip() == '2'
    else:
        assert reason in result.stderr
        assert (tmp_path/'count').read_text().strip() == ('2' if mode == 'copy' else '1')


class MemorySamplingTests(unittest.TestCase):
    def test_changing_memory_snapshots(self):
        for worker in ['prime-worker.sh', 'chat-worker.sh']:
            for mode, ok, reason in [('stale', True, ''), ('copy', False, 'Additional runtime RSS'),
                                     ('unsafe', False, 'not read-only/shared'), ('low', False, 'Low allocatable GDDR')]:
                with self.subTest(worker=worker, mode=mode), tempfile.TemporaryDirectory(prefix='phichat-memory-') as directory:
                    check_memory_snapshot_refresh(Path(directory), worker, mode, ok, reason)


if __name__ == '__main__':
    unittest.main()
