"""Preparation transport count and boot-bound allocation reuse; no Phi inference."""
from pathlib import Path
import json
import pytest
from test_job_fixture import setup_app, load_model, run_job, assert_chat_ok, change_fixture


def test_normal_chat_uses_one_preparation_ssh_and_one_upload(tmp_path: Path) -> None:
    f=setup_app(tmp_path);load_model(f,'load')
    (f['remote']/'commands.txt').write_text('')
    result,status,job=run_job(f,'chat')
    assert_chat_ok(result,status,job,f)
    commands=(f['remote']/'commands.txt').read_text()
    assert commands.count('# PHICHAT_PREPARE_V1')==1
    assert "if test -x" not in commands
    exits=[json.loads(p.read_text()) for p in sorted(job.glob('process-*.exit.json'))]
    # Preflight SSH + request SCP precede guarded generation. Report/cleanup follow.
    assert [r['guarded'] for r in exits].index(True)==2
    assert len(exits)==7  # includes confirmation that the workload lease was released
    assert 'OpenSSH_' not in ''.join(p.read_text() for p in job.glob('process-*.stderr.txt'))
    timing=json.loads((job/'preparation-timing.json').read_text())
    assert timing['seconds_to_generation_launch']>0
    assert status['result']['preparation_seconds']==timing['seconds_to_generation_launch']


@pytest.mark.parametrize('change',['none','boot','missing_boot','batch','main','model','long_prompt'])
def test_4k_allocation_reuse_is_bounded(tmp_path: Path,change: str) -> None:
    f=setup_app(tmp_path);load_model(f,'load')
    result,status,job=run_job(f,'first',context_tokens=4096)
    assert_chat_ok(result,status,job,f)
    assert len(json.loads((f['remote']/'checks.json').read_text()))==1
    args={'context_tokens':4096}
    if change=='boot': change_fixture(f,boot_id='22222222-2222-2222-2222-222222222222')
    if change=='missing_boot': change_fixture(f,boot_id='')
    if change=='batch': args['batch']=64
    if change=='main':
        with (f['runtime']/'llama/main').open('a') as out: out.write('changed executable metadata')
    if change=='model':
        # A preserved model's metadata change invalidates the receipt even when
        # bytes/identity remain correct. No full model hash during Send.
        import os
        os.utime(f['runtime']/'model.gguf',(1000000000,1000000000))
    if change=='long_prompt': args['messages']=[{'role':'user','content':'test question '+'界'*1700}]
    result,status,job=run_job(f,'second',**args)
    assert_chat_ok(result,status,job,f)
    assert len(json.loads((f['remote']/'checks.json').read_text()))==(1 if change=='none' else 2)
    assert (job/'prompt-check-1').exists()==(change!='none')


@pytest.mark.parametrize('change',['runtime','weights','memory','architecture'])
def test_fast_preparation_rejects_changed_card_state(tmp_path: Path,change: str) -> None:
    f=setup_app(tmp_path);load_model(f,'load')
    if change=='runtime': (f['runtime']/'build-passed.txt').write_text('f'*40)
    if change=='weights': (f['runtime']/'model.gguf').unlink()
    if change=='memory': change_fixture(f,free_kib=1)
    if change=='architecture': change_fixture(f,architecture='x86_64')
    (f['remote']/'commands.txt').write_text('')
    result,status,job=run_job(f,'rejected')
    assert result.returncode!=0
    assert not any(line.startswith('exec ') for line in (f['remote']/'commands.txt').read_text().splitlines())
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()
