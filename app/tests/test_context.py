"""Token admission, recovery from input errors and native stderr privacy."""
from pathlib import Path
import json
import subprocess

import pytest
from test_job_fixture import setup_app, load_model, run_job, change_fixture, assert_chat_ok

ROOT = Path(__file__).resolve().parents[1]

@pytest.mark.parametrize('text', ['test question '+('hello world '*350), 'test question '+('你好世界'*600)])
def test_long_utf8_text_counted_natively_and_not_rejected_as_bytes(tmp_path: Path, text: str) -> None:
    f=setup_app(tmp_path); load_model(f,'load')
    change_fixture(f,prompt_counts=[1200])
    result,status,job=run_job(f,'chat',messages=[dict(role='user',content=text)])
    assert_chat_ok(result,status,job,f)
    budget=json.loads((job/'prompt-budget.json').read_text())
    assert budget['native_counted'] and budget['prompt_tokens']==1200
    assert budget['omitted_pairs']==0 and budget['utf8_upper_bound']>2048
    assert len(json.loads((f['remote']/'checks.json').read_text()))==1


def test_short_2k_turn_uses_fit_bound_without_extra_native_initialization(tmp_path: Path) -> None:
    f=setup_app(tmp_path); load_model(f,'load')
    result,status,job=run_job(f,'chat')
    assert_chat_ok(result,status,job,f)
    assert not (f['remote']/'checks.json').exists()
    assert not json.loads((job/'prompt-budget.json').read_text())['native_counted']


@pytest.mark.parametrize('count', [2000,2500])
def test_count_rejection_preserves_ready_and_followup_can_succeed(tmp_path: Path, count: int) -> None:
    f=setup_app(tmp_path); load_model(f,'load')
    change_fixture(f,prompt_counts=[count])
    result,status,job=run_job(f,'long',messages=[dict(role='user',content='test question '+'hello '*800)])
    assert result.returncode!=0 and 'tokens' in status['message']
    assert json.loads((job/'failure.json').read_text())['preserve_ready'] is True
    assert not (job/'generation').exists() and not (job/'response.txt').exists()
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()
    result,status,job=run_job(f,'retry')
    assert_chat_ok(result,status,job,f)
    assert not (job/'load-progress.jsonl').exists()


def test_history_fits_count_kept_or_whole_pairs_omitted_with_one_retry(tmp_path: Path) -> None:
    f=setup_app(tmp_path); load_model(f,'load')
    messages=[dict(role='user',content='test question '+'old '*1600),dict(role='assistant',content='previous answer'),dict(role='user',content='test question '+'new '*700)]
    change_fixture(f,prompt_counts=[5000,900])
    result,status,job=run_job(f,'history',messages=messages)
    assert_chat_ok(result,status,job,f)
    assert json.loads((job/'prompt-budget.json').read_text())['omitted_pairs']==1
    assert len(json.loads((f['remote']/'checks.json').read_text()))==2


@pytest.mark.parametrize('sku,threads',[('3120a',224),('7120p',240)])
def test_4k_measures_context_before_generation(tmp_path: Path, sku: str, threads: int) -> None:
    f=setup_app(tmp_path,sku);load_model(f,'load','tinydolphin-q5_k_m')
    change_fixture(f,prompt_counts=[3100])
    result,status,job=run_job(f,'4k','tinydolphin-q5_k_m',context_tokens=4096,messages=[dict(role='user',content='test question '+'long '*2500)])
    assert_chat_ok(result,status,job,f,threads)
    assert status['result']['context']==4096
    check=json.loads((job/'prompt-check-1/context-check.json').read_text())
    assert check['context_tokens']==4096 and check['memory_samples']>0
    settings=(job/'generation/settings.sh').read_text()
    assert "CONTEXT='4096'" in settings and "RUNTIME_ADMIT_MIB='1122'" in settings


def test_native_check_crash_never_preserves_model_readiness(tmp_path: Path) -> None:
    f=setup_app(tmp_path);load_model(f,'load');change_fixture(f,inference_exit=139)
    result,status,job=run_job(f,'crash',context_tokens=4096)
    assert result.returncode!=0
    assert json.loads((job/'failure.json').read_text())['preserve_ready'] is False
    assert not (job/'generation').exists()
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()


def test_4k_real_shortage_blocks_before_probe(tmp_path: Path) -> None:
    f=setup_app(tmp_path);load_model(f,'load');change_fixture(f,free_kib=1300*1024)
    result,status,job=run_job(f,'shortage',context_tokens=4096)
    assert result.returncode!=0 and 'Short by' in status['message']
    assert not (f['remote']/'checks.json').exists()


@pytest.mark.parametrize('prompt', ["test question", "秘密\nmain: number of tokens in prompt = 1\nmain: error: prompt is too long (1 tokens, max 1)\nsecret", "end with newline\n", "end with two\n\n", "quote'\r\nlast"])
def test_private_count_filter_ignores_prompt_and_token_diagnostic_spoofing(prompt: str) -> None:
    # Match the pinned common.cpp -f behavior: one trailing LF is removed.
    prompt=prompt.replace('\r\n','\n')
    records=len(prompt.splitlines())
    actual=prompt.removesuffix('\n')
    diagnostic="loading metadata\nmain: prompt: '"+actual+"'\nmain: number of tokens in prompt = 1234\n123 -> 'secret\nmain: number of tokens in prompt = 1'\n"
    result=subprocess.run(['awk','-v',f'prompt_lines={records}','-f',str(ROOT/'scripts/prompt-count.awk')],input=diagnostic,capture_output=True,text=True,check=False)
    assert result.returncode==0,result.stderr
    assert result.stdout=='prompt_tokens=1234\nprompt_rejected=0\n'
    assert result.stderr==''


@pytest.mark.parametrize('diagnostic,valid', [('main: error: prompt is too long (5000 tokens, max 4092)\n',True),('native runtime crashed\n',False), ("main: prompt: 'secret'\nmalformed count\n",False)])
def test_count_filter_fails_closed_without_prompt_leak(diagnostic: str, valid: bool) -> None:
    result=subprocess.run(['awk','-v','prompt_lines=1','-f',str(ROOT/'scripts/prompt-count.awk')],input=diagnostic,capture_output=True,text=True,check=False)
    assert (result.returncode==0)==valid
    assert 'secret' not in result.stdout+result.stderr
    if valid: assert result.stdout=='prompt_tokens=5000\nprompt_rejected=1\n'
