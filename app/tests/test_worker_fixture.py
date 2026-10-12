"""Exercise the shell worker with an explicit byte-mapping process, never an LLM.

Only the test copy substitutes path roots and the K1OM/ELF platform boundary.
The shipped worker always enforces the real boundary.
"""
from pathlib import Path
import os
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[1]

DUMMY = r'''#!/usr/bin/env python3
import mmap, os, pathlib, sys, time
if '--help' in sys.argv:
    print('--no-mmap --verbose-prompt --rope-scaling --print-token-count');sys.exit(0)
assert '--no-mmap' not in sys.argv
assert '--log-enable' in sys.argv and '--log-disable' not in sys.argv
assert pathlib.Path('main.log').resolve()==pathlib.Path('/dev/null')
assert pathlib.Path('llama.log').resolve()==pathlib.Path('/dev/null')
with open('main.log','w') as trace: trace.write('private fixture prompt marker')
model=sys.argv[sys.argv.index('-m')+1]
mode=os.environ['MAP_FIXTURE_MODE']
with open(model,'rb') as f:
    if mode=='copy': data=f.read()
    else:
        data=mmap.mmap(f.fileno(),0,flags=mmap.MAP_SHARED if mode=='shared' else mmap.MAP_PRIVATE,prot=mmap.PROT_READ)
    assert sum(data[i] for i in range(0,len(data),4096))>0
    pathlib.Path('fixture-smaps.new').write_text(pathlib.Path('/proc/self/smaps').read_text())
    pathlib.Path('fixture-smaps.new').replace('fixture-smaps')
    if '--verbose-prompt' in sys.argv:
        prompt=pathlib.Path(sys.argv[sys.argv.index('-f')+1]).read_text().removesuffix('\n')
        print("main: prompt: '"+prompt+"'",file=sys.stderr)
        print('main: number of tokens in prompt = 700',file=sys.stderr)
        print("123 -> 'private fixture prompt marker'",file=sys.stderr)
    print('generate: n_ctx = 2048', file=sys.stderr, flush=True)
    print('Tokens consumed so far = 64 / 2048', file=sys.stderr, flush=True)
    print('fixture',end='',flush=True)
    time.sleep(2.5)
    print(' answer',flush=True)
    print('llama_print_timings: eval time = 100 ms / 2 runs (50 ms per token, 20.00 tokens per second)',file=sys.stderr)
'''


@pytest.mark.parametrize('modern', [False, True])
@pytest.mark.parametrize('mode', ['shared', 'private', 'copy'])
@pytest.mark.parametrize('context,run_mode', [(2048,'generate'),(4096,'check')])
def test_worker_mapping_and_additional_rss_limit(tmp_path: Path, mode: str, context: int, run_mode: str, modern: bool) -> None:
    if modern: context=2048
    runtime=tmp_path/'root/knc-phase3-run-fixture'
    job=tmp_path/'root/knc-chat-abcdef'
    (runtime/'llama').mkdir(parents=True)
    job.mkdir(parents=True)
    pin='03a8b80c7d502797325788f604248dd4aabdf5ef'
    token='a'*32
    (runtime/'build-passed.txt').write_text(pin)
    model=runtime/'model.gguf'
    model.write_bytes(b'x'*(64*1024*1024))
    main=runtime/'llama/main';main.write_text(DUMMY);main.chmod(0o755)
    if modern:
        dummy=DUMMY.replace("    if '--verbose-prompt' in sys.argv:","    if '--verbose-prompt' in sys.argv:\n        print('PHI_PROMPT_TOKENS 700',file=sys.stderr)")
        dummy=dummy.replace("assert '--no-mmap' not in sys.argv","assert [sys.argv[i+1] for i,a in enumerate(sys.argv) if a=='--stop-token']==['128001','128008','128009']\nassert '--no-mmap' not in sys.argv")
        dummy=dummy.replace("assert '--log-enable' in sys.argv","assert ('--baseline-kernels' in sys.argv) == ('--verbose-prompt' not in sys.argv)\nassert '--log-enable' in sys.argv")
        new=runtime/'llama/phi-modern';new.write_text(dummy);new.chmod(0o755)
        main.write_text('#!/bin/sh\necho LEGACY_ENGINE_MUST_NOT_RUN >&2\nexit 92\n')
        (runtime/'modern-source.txt').write_text('6783b11fb0889d68d0046176b4cc92ceee1961b0')
        (runtime/'modern-runtime-passed.txt').write_text('phichat142-modern-'+('b'*16))
    lock=tmp_path/'lock';lock.mkdir();(lock/'phi-chat-owner').write_text(token)
    bindir=tmp_path/'bin';bindir.mkdir()
    wc=bindir/'wc';wc.write_text('#!/bin/sh\necho FULL_FILE_SCAN_FORBIDDEN >&2\nexit 91\n');wc.chmod(0o755)
    uname=bindir/'uname';uname.write_text('#!/bin/sh\necho k1om\n');uname.chmod(0o755)
    (job/'elf-check.sh').write_text('# TEST fixture only; no model executable\ncheck_elf() { :; }\n')
    for name in ['memory-info.awk','model-map.awk','prompt-count.awk','engine-llama-cli-v1.sh']:
        (job/name).write_bytes((ROOT/'scripts'/name).read_bytes())
    worker=(ROOT/'scripts/chat-worker.sh').read_text()
    worker=worker.replace('/root/',str(tmp_path)+'/root/').replace('/tmp/knc-phase3-workload.lock',str(lock))
    # This development sandbox hides other PIDs in procfs. Feed the test worker
    # the dummy process's own real smaps snapshot; production reads proc directly.
    worker=worker.replace('/proc/$model_pid/smaps', '$job/fixture-smaps')
    (job/'fixture-smaps').write_text('1000-2000 rw-p 0 00:00 0 [heap]\nSize: 1024 kB\nRss: 1024 kB\n')
    (job/'worker.sh').write_text(worker)
    settings=dict(LOCK_TOKEN=token,SOURCE_COMMIT=pin,MODEL_PATH=str(model),MODEL_BYTES=model.stat().st_size,
                  CONTEXT=context,RUN_MODE=run_mode,THREADS=224,PROMPT_THREADS=224,CORES=57,PREDICT=64,BATCH=128,SEED=1234,
                  RUNTIME_ADMIT_MIB=1,RUNTIME_LIMIT_MIB=50,MEMORY_STOP_MIB=256)
    if modern: settings.update(MODERN_TEST_MODE='baseline',STOP_TOKEN_IDS='128001,128008,128009',RUNTIME_FAMILY='modern-knc',MODERN_RUNTIME_ID='phichat142-modern-'+('b'*16),THREADS=168,PROMPT_THREADS=168,BATCH=32)
    (job/'settings.sh').write_text(''.join(f"{k}='{v}'\n" for k,v in settings.items()))
    (job/'prompt.txt').write_text('private fixture prompt marker')
    result=subprocess.run(['bash',str(job/'worker.sh'),str(runtime),str(job)],capture_output=True,text=True,
                          env=dict(os.environ,PATH=str(bindir)+os.pathsep+os.environ['PATH'],MAP_FIXTURE_MODE=mode),
                          timeout=12,check=False)
    assert not (job/'prompt.txt').exists()
    assert lock.exists() == (run_mode=='check')
    assert not (job/'prompt.stderr').exists()
    if mode=='shared':
        assert result.returncode==0,(result.stdout,result.stderr)
        assert 'read-only shared model mapping' in (job/'report/model-mapping.txt').read_text()
        if run_mode=='generate':
            assert 'tokens per second' in (job/'report/timing.txt').read_text()
            assert 'fixture answer' in result.stdout
            assert 'PHICHAT_PROGRESS prefill 64 ' in result.stderr
        else:
            assert result.stdout==''
            assert (job/'report/prompt-count.txt').read_text()=='prompt_tokens=700\nprompt_rejected=0\nnative_exit_code=0\n'
            assert ('context='+str(context)) in (job/'report/settings.txt').read_text()
        # 64 MiB mapped weight pages exceed the 50 MiB additional-runtime limit,
        # yet sharing them is accepted. A second 64 MiB allocation is rejected.
    else:
        assert result.returncode!=0
        expected='not read-only/shared' if mode=='private' else 'Additional runtime RSS'
        assert expected in result.stderr,result.stderr
    assert all('private fixture prompt marker' not in p.read_text(errors='replace')
               for p in (job/'report').iterdir())
