"""Installer failures are observable; all native/card work is explicitly mocked."""
import json, os, shutil, subprocess
from pathlib import Path
import pytest
from test_job_fixture import ROOT, PWSH
pytestmark=pytest.mark.skipif(not PWSH,reason='PowerShell required')

def run(script,args=(),env=None):
 return subprocess.run([str(PWSH),'-NoProfile','-File',str(script),*args],capture_output=True,text=True,env=dict(os.environ,DOTNET_PROCESSOR_COUNT='2',**(env or {})),timeout=45)

@pytest.mark.parametrize('mode',['success','failed','missing-status','missing-selection'])
def test_installer_requires_complete_success(tmp_path,mode):
 app=tmp_path/'app with spaces';shutil.copytree(ROOT,app)
 data=tmp_path/'data';data.mkdir();(app/'config/connection.yaml').write_text(json.dumps({'data_dir':str(data)}))
 installer=app/'Install-ModernRuntime.ps1'
 t=installer.read_text();start=t.index('    if ([Environment]::OSVersion.Platform');end=t.index('\n',start)
 installer.write_text(t[:start]+'    function Get-CimInstance {}'+t[end:])
 bindir=tmp_path/'bin';bindir.mkdir();exe=bindir/'powershell.exe'
 exe.write_text('''#!/usr/bin/env python3
import sys,pathlib,json,os
job=pathlib.Path(sys.argv[sys.argv.index('-JobDir')+1]);mode=os.environ['FIXTURE_MODE']
if mode!='missing-status':(job/'status.json').write_text(json.dumps({'state':'failed' if mode=='failed' else 'done','message':'fixture native exit 7' if mode=='failed' else 'fixture passed'}))
if mode=='success':(job/'modern-selection.json').write_text(json.dumps({'enabled':True,'validation':'native-kernels-dispatch-and-cli-startup'}))
sys.exit(7 if mode=='failed' else 0)
''');exe.chmod(0o755)
 r=run(installer,env={'PATH':str(bindir)+os.pathsep+os.environ['PATH'],'FIXTURE_MODE':mode})
 assert (r.returncode==0)==(mode=='success'),r.stdout+r.stderr
 assert list(data.glob('jobs/*/installer-console.txt'))
 if mode=='failed':assert 'fixture native exit 7' in r.stdout
 if mode!='success':assert 'FAIL:' in r.stdout and 'PASS:' not in r.stdout

def test_guard_recovery(tmp_path):
 r=run(ROOT/'tests/Test-RuntimeGuard.ps1',['-Scratch',str(tmp_path/'guard with spaces')]);assert r.returncode==0,r.stdout+r.stderr

@pytest.mark.parametrize('failure',['','modern-operators','integration-benchmark'])
def test_native_install_stages_and_receipts(tmp_path,failure):
 import tarfile, uuid
 runtime=Path('/root')/('knc-phase3-run-modern142-'+uuid.uuid4().hex)
 runtime.mkdir()
 try:
  token='a'*32;commit='03a8b80c7d502797325788f604248dd4aabdf5ef';identity='phichat142-modern-'+'b'*16
  lock=tmp_path/'lock';lock.mkdir();(lock/'phi-chat-owner').write_text(token)
  bindir=tmp_path/'bin';bindir.mkdir();uname=bindir/'uname';uname.write_text('#!/bin/sh\necho k1om\n');uname.chmod(0o755)
  (runtime/'guard-source.txt').write_text(commit);(runtime/'guard').write_text('mock guard, never executed')
  (runtime/'elf-check.sh').write_text('check_elf() { test -f "$1"; }\n')
  (runtime/'memory-info.awk').write_text('END { print "5000000 5000000 0" }\n')
  payload=tmp_path/'payload';payload.mkdir()
  for name in ['llama/main','llama/llama-bench','llama/test-phase3-numerics','llama/test-quantize-fns','llama/phi-modern','tests/test-knc','tests/test-modern-ops','lib/libgomp.so.1']:
   p=payload/name;p.parent.mkdir(exist_ok=True)
   code='#!/bin/sh\necho "mock native test"\n'
   if name=='tests/test-modern-ops':
    if failure=='modern-operators':code+='exit 7\n'
    if failure=='integration-benchmark':code+='if [ "$1" = "--bench" ]; then echo "fixture regression >5%"; exit 4; fi\n'
   p.write_text(code);p.chmod(0o755)
  (payload/'runtime-id.txt').write_text(identity)
  (payload/'modern-source.txt').write_text('6783b11fb0889d68d0046176b4cc92ceee1961b0')
  archive=runtime/'runtime-3120A.tar'
  with tarfile.open(archive,'w') as tar:
   for p in payload.iterdir():tar.add(p,arcname=p.name)
  script=tmp_path/'install.sh';script.write_text((ROOT/'scripts/modern-runtime-install.sh').read_text().replace('lock=/tmp/knc-phase3-workload.lock',f'lock={lock}'))
  r=subprocess.run(['bash',str(script),str(runtime),str(runtime),token,archive.name,identity,commit],capture_output=True,text=True,env=dict(os.environ,PATH=str(bindir)+os.pathsep+os.environ['PATH']))
  assert (r.returncode==0)==(not failure),r.stdout+r.stderr
  assert (runtime/'modern-runtime-passed.txt').exists()==(not failure)
  assert not (lock/'worker-pid').exists()
  if failure:assert 'FAIL: stage='+failure in r.stderr
  if failure=='integration-benchmark':assert 'fixture regression >5%' in r.stderr
 finally:shutil.rmtree(runtime)
