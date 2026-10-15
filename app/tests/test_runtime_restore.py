"""Run the real restore shell against local fake binaries; no card access."""
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

import pytest

ROOT = Path(__file__).resolve().parents[1]
BASH = (str(Path(os.environ.get('ProgramFiles', 'C:/Program Files')) / 'Git/bin/bash.exe')
        if os.name == 'nt' else shutil.which('bash'))
pytestmark = pytest.mark.skipif(not BASH or not Path(BASH).is_file(), reason='Bash required')
SOURCES = ['d57e0e6e4882445bc625aaee47f91db469f9fc22',
           '61e97998bf49c2d425563920b7e83e52b5ae57a6']


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode('utf-8'))
    path.chmod(0o755)


def shpath(path):
    value = path.as_posix()
    return '/' + value[0].lower() + value[2:] if os.name == 'nt' else value


@pytest.mark.parametrize('source,mode,failure', [
    (source, mode, '') for source in SOURCES for mode in ['', 'restore']
] + [(SOURCES[1], 'restore', failure) for failure in
     ['identity', 'source', 'capability', 'startup']] + [(SOURCES[1], 'invalid', '')])
def test_restore_startup_and_qualification(tmp_path, source, mode, failure):
    runtime = tmp_path / 'runtime'
    lock = tmp_path / 'lock'
    payload = tmp_path / 'payload'
    trace = tmp_path / 'calls.txt'
    commit = '03a8b80c7d502797325788f604248dd4aabdf5ef'
    identity = 'phichat142-modern-' + 'b' * 16
    write(lock / 'phi-chat-owner', 'a' * 32)
    write(runtime / 'guard-source.txt', commit)
    write(runtime / 'guard', 'fixture guard; never executed')
    write(runtime / 'elf-check.sh', 'check_elf() { test -f "$1"; }\n')
    write(runtime / 'memory-info.awk', 'END { print "5000000 5000000 0" }\n')
    binaries = ['llama/main', 'llama/llama-bench', 'llama/test-phase3-numerics',
                'llama/test-quantize-fns', 'llama/phi-modern', 'tests/test-knc',
                'tests/test-modern-ops', 'tests/test-q5-repair', 'lib/libgomp.so.1',
                'shared/lib/libgomp.so.1']
    binaries += ['shared/bin/' + name for name in
                 ['phi-modern', 'test-modern-ops', 'test-knc-dot', 'test-knc-mq',
                  'test-backend-ops', 'test-quantize-fns', 'test-sampling', 'test-knc-mtmd']]
    for name in binaries:
        code = '#!/bin/sh\nprintf "%s\\n" "' + name + ' $*" >> "$TRACE"\n'
        code += 'printf "%s\\n" "auto-resources-v1 fixture"\n'
        if name == 'shared/bin/phi-modern':
            if failure == 'capability':
                code = code.replace('auto-resources-v1', 'missing-capability')
            if failure == 'startup':
                code += 'exit 7\n'
        write(payload / name, code)
    write(payload / 'runtime-id.txt', 'wrong' if failure == 'identity' else identity)
    write(payload / 'shared-runtime-id.txt', identity)
    write(payload / 'parent-runtime-id.txt', 'phichat142-modern-9610d4c7df2513c6')
    write(payload / 'modern-source.txt', 'wrong' if failure == 'source' else source)
    write(payload / 'q5-repair.json', '{}')
    archive = runtime / 'runtime-7120P.tar'
    with tarfile.open(str(archive), 'w') as tar:
        for path in payload.iterdir():
            tar.add(str(path), arcname=path.name)
    script = (ROOT / 'scripts/modern-runtime-install.sh').read_text()
    # Redirect only the card-specific path checks and lock to this disposable tree.
    script = 'uname() { printf "k1om\\n"; }\n' + script
    script = script.replace('lock=/tmp/knc-phase3-workload.lock', "lock='" + shpath(lock) + "'")
    script = script.replace('[[ $runtime =~ ^/root/knc-phase3-run-modern14[012]-[a-f0-9]{32}$ ]]',
                            '[[ $runtime == "$FIXTURE_RUNTIME" ]]')
    script = script.replace('[[ $baseline =~ ^/root/knc-phase3-run-[A-Za-z0-9-]+$ ]]',
                            '[[ $baseline == "$FIXTURE_RUNTIME" ]]')
    installer = tmp_path / 'install.sh'
    write(installer, script)
    args = [BASH, shpath(installer), shpath(runtime), shpath(runtime),
            'a' * 32, archive.name, identity, commit, source]
    if mode:
        args.append(mode)
    env = dict(os.environ, TRACE=shpath(trace), FIXTURE_RUNTIME=shpath(runtime))
    result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=30)
    success = not failure and mode != 'invalid'
    assert (result.returncode == 0) == success, result.stdout + result.stderr
    assert (runtime / 'modern-runtime-passed.txt').exists() == success
    assert not (lock / 'worker-pid').exists()
    if failure:
        expected = {'identity': 'payload identity', 'source': 'modern source pin',
                    'capability': 'Automatic allocation capability missing',
                    'startup': 'stage=modern-cli-startup exit=7'}
        assert expected[failure] in result.stderr
    if mode == 'invalid':
        assert 'Unsupported installation mode' in result.stderr
    calls = trace.read_text().splitlines() if trace.exists() else []
    if mode == 'restore':
        assert not any('test-' in call for call in calls), calls
        if success:
            assert calls == ['llama/main --help', 'shared/bin/phi-modern --describe',
                             'shared/bin/phi-modern --help']
            assert 'numerical tests were not rerun' in result.stdout
    elif mode == '':
        assert sum('test-knc-mq ' in call for call in calls) == 4
        assert any('test-phase3-numerics' in call for call in calls)
        assert any('test-quantize-fns' in call for call in calls)
        assert any('test-knc-mtmd' in call for call in calls) == (source == SOURCES[1])
