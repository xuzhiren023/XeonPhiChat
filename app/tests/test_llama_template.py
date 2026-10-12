"""Exact text-only formatter comparison against the pinned publisher template."""
import json,os,subprocess
from pathlib import Path
import pytest
from test_job_fixture import ROOT,PWSH
jinja2=pytest.importorskip('jinja2')
@pytest.mark.skipif(not PWSH,reason='PowerShell required')
@pytest.mark.parametrize('system',['','Be helpful.','  Unicode 系统\n'])
@pytest.mark.parametrize('assistant',[None,'   12   ','<think>literal Llama content</think>Answer','Answer\nwith a line'])
def test_llama_exact_template(tmp_path,system,assistant):
 messages=[{'role':'user','content':' Compute 7 plus 5. ☃ '}]
 if assistant:messages +=[{'role':'assistant','content':assistant},{'role':'user','content':'Another question\n  '}]
 spec=tmp_path/'case.json';out=tmp_path/'out.json';spec.write_text(json.dumps(dict(system=system,messages=messages)))
 script=". (Join-Path $env:PHI_APP 'lib/ChatCore.ps1'); $m=Get-ModelProfile $env:PHI_APP 'llama-3.3-8b-abliterated-q2_k';$c=Read-JsonFile $env:PHI_CASE;Write-JsonFile $env:PHI_OUT (New-ChatPrompt $m @($c.messages) $c.system)"
 subprocess.run([str(PWSH),'-NoProfile','-Command',script],check=True,env=dict(os.environ,PHI_APP=str(ROOT),PHI_CASE=str(spec),PHI_OUT=str(out),DOTNET_PROCESSOR_COUNT='2'))
 actual=json.loads(out.read_text(encoding='utf-8-sig'))['text']
 t=jinja2.Environment().from_string((ROOT/'tests/fixtures/llama-checkpoint-template.jinja').read_text())
 expected=t.render(bos_token='<|begin_of_text|>',messages=[dict(role='system',content=system)]+messages,add_generation_prompt=True)
 assert actual==expected
