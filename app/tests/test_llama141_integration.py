"""Execute real Windows orchestration with fake SSH, never claim card inference."""
import json
import pytest
from test_job_fixture import setup_app, run_job, load_model, assert_chat_ok, ROOT, PWSH
pytestmark=pytest.mark.skipif(not PWSH,reason='PowerShell required')

@pytest.mark.parametrize('sku,model,threads',[('3120a','llama-3.3-8b-abliterated-q2_k',168),('7120p','llama-3.3-8b-abliterated-q5_k_m',180)])
def test_modern_llama_load_chat_repeat_without_hash(tmp_path,sku,model,threads):
 f=setup_app(tmp_path,sku)
 pin=json.loads((f['app']/'config/modern-runtime.json').read_text());payload=next(x for x in pin['payloads'] if x['profile']=='xeon-phi-'+sku)
 selection=dict(schema_version=1,enabled=True,version=pin["version"],source_commit=pin['source_commit'],serial='TEST-CARD',profile=payload['profile'],archive_sha256=payload['sha256'],runtime_id=payload['runtime_id'],validation='native-kernels-dispatch-and-cli-startup',remote_base='/root/knc-phase3-run-fixture')
 dest=f['data']/'modern-runtime/active-TEST-CARD.json';dest.parent.mkdir();dest.write_text(json.dumps(selection))
 (f['runtime']/'llama/phi-modern').write_text('fixture');(f['runtime']/'llama/phi-modern').chmod(0o755)
 ssh=tmp_path/'bin/ssh.exe';s=ssh.read_text().replace("expected='240' if cfg.get('sku')=='7120p' else '224'",f"expected='{threads}'")
 s=s.replace("assert settings['THREADS']==expected", "assert settings['STOP_TOKEN_IDS']=='128001,128008,128009'\n    assert settings['RUNTIME_FAMILY']=='modern-knc'\n    assert '<|begin_of_text|>' in (job/'prompt.txt').read_text()\n    assert '<|start_header_id|>assistant<|end_header_id|>' in (job/'prompt.txt').read_text()\n    assert '<|im_start|>' not in (job/'prompt.txt').read_text()\n    assert settings['THREADS']==expected")
 ssh.write_text(s)
 load_model(f,'load',model)
 # Make any attempted SHA during Chat fatal: these are actual child job runs.
 core=f['app']/'lib/ChatCore.ps1';core.write_text(core.read_text()+"\nfunction Get-FileHash { throw 'Repeated SHA during Send is forbidden by test' }\n")
 for n in range(2):
  result,status,job=run_job(f,'chat'+str(n),model)
  assert_chat_ok(result,status,job,f,threads)
  assert status['result']['runtime_family']=='modern-knc'
  assert not (job/'load-progress.jsonl').exists()
 commands=(f['remote']/'commands.txt').read_text()
 assert 'sha256sum' not in commands and 'test-knc' not in commands
