"""Run real orchestration with tiny model files and explicit fake SSH/MPSS.

The fake SSH handles generation itself; no Phi or host LLM inference is executed.
"""
from pathlib import Path
from typing import Any
import hashlib
import json
import os
import shutil
import subprocess
import struct

import pytest

ROOT = Path(__file__).resolve().parents[1]
PWSH = os.environ.get('PHI_TEST_PWSH') or shutil.which('pwsh')
pytestmark = pytest.mark.skipif(not PWSH, reason='Set PHI_TEST_PWSH for the orchestration fixture')

SSH = r'''#!/usr/bin/env python3
import json, os, pathlib, shlex, subprocess, sys, time
cfg=json.loads(pathlib.Path(os.environ['PHI_FIXTURE']).read_text())
remote=pathlib.Path(cfg['remote'])
def mapped(p): return remote / p.lstrip('/')
if '-V' in sys.argv:
    print('OpenSSH_9.6p1',file=sys.stderr);sys.exit(0)
c=sys.argv[-1]
with (remote/'commands.txt').open('a') as f: f.write(c+'\n')
if c == 'uname -m': print(cfg.get('architecture','k1om'))
elif c == 'cat /proc/meminfo':
    free=cfg.get('free_kib',5500000)
    total=16000000 if cfg.get('sku')=='7120p' else 5879692
    print(cfg.get('meminfo',f'MemTotal: {total} kB\nMemFree: {free} kB\nCached: 200000 kB\nShmem: 200000 kB\nUnevictable: 0 kB\nDirty: 0 kB\nWriteback: 0 kB\nActive(file): 0 kB\nInactive(file): 0 kB\n'))
elif c.startswith('exec '):
    parts=shlex.split(c); job=mapped(parts[-1]); report=job/'report';report.mkdir()
    settings=dict(line.split('=',1) for line in (job/'settings.sh').read_text().splitlines())
    settings={k:v.strip("'") for k,v in settings.items()}
    expected='240' if cfg.get('sku')=='7120p' else '224'
    assert settings['THREADS']==expected and settings['PROMPT_THREADS']==expected
    assert (job/'prompt.txt').read_text().find('test question') >= 0
    lock=mapped('/tmp/knc-phase3-workload.lock')
    assert (lock/'phi-chat-owner').read_text().strip()==settings['LOCK_TOKEN']
    assert mapped(settings['MODEL_PATH']).stat().st_size==int(settings['MODEL_BYTES'])
    sys.stdin.readline()
    if cfg.get('slow_inference'):
        (remote/'inference-running').write_text('fixture')
        # Simulate guard EOF handling. No model runs on the test host.
        while sys.stdin.readline(): pass
        (remote/'inference-stopped').write_text('heartbeat input closed')
    code=cfg.get('inference_exit',0)
    (report/'exit-code.txt').write_text('exit_code='+str(code)+'\n')
    timing='llama_print_timings: load time = 20.0 ms\n'
    if not cfg.get('no_timing'):
        timing+='llama_print_timings: prompt eval time = 100.0 ms / 10 tokens (10.0 ms per token, 100.0 tokens per second)\nllama_print_timings: eval time = 200.0 ms / 20 runs (10.0 ms per token, 100.0 tokens per second)\n'
    if code: timing+='fixture native runtime error\n'
    (report/'timing.txt').write_text(timing)
    (report/'model-mapping.txt').write_text('PASS: read-only shared model mapping observed\n' if not cfg.get('missing_mapping') else 'not observed\n')
    (report/'memory.csv').write_text('epoch,memfree_kib,vmrss_kib,vmhwm_kib,model_rss_kib,additional_rss_kib\n1,2000000,1000000,1000000,600000,400000\n')
    (job/'prompt.txt').unlink()
    if settings.get('RUN_MODE')=='check':
        checks=remote/'checks.json'
        count_index=len(json.loads(checks.read_text())) if checks.exists() else 0
        counts=cfg.get('prompt_counts',[700])
        count=counts[min(count_index,len(counts)-1)]
        prior=json.loads(checks.read_text()) if checks.exists() else []
        checks.write_text(json.dumps(prior+[dict(context=settings['CONTEXT'],count=count)]))
        rejected=count>int(settings['CONTEXT'])-4
        (report/'prompt-count.txt').write_text(f'prompt_tokens={count}\nprompt_rejected={int(rejected)}\nnative_exit_code={int(rejected)}\n')
        sys.exit(code)
    (lock/'phi-chat-owner').unlink();lock.rmdir()
    print('Fixture answer: unicode café.',flush=True)
    sys.exit(code)
else:
    # Execute actual staging/lock shell commands only, redirected into the fixture.
    assert 'exec ' not in c
    c=c.replace('/root/',str(remote/'root')+'/').replace('/tmp/knc-phase3-workload.lock',str(remote/'tmp/knc-phase3-workload.lock'))
    c=c.replace('/tmp/phi-chat-cache-',str(remote/'tmp/phi-chat-cache-'))
    if '# PHICHAT_PREPARE_V1' in c:
        free=cfg.get('free_kib',5500000)
        total=16000000 if cfg.get('sku')=='7120p' else 5879692
        (remote/'meminfo').write_text(cfg.get('meminfo',f'MemTotal: {total} kB\nMemFree: {free} kB\nCached: 0 kB\n'))
        (remote/'boot-id').write_text(cfg.get('boot_id','11111111-1111-1111-1111-111111111111')+'\n')
        c=c.replace('uname -m', 'printf '+shlex.quote(cfg.get('architecture','k1om')))
        c=c.replace('/proc/meminfo',str(remote/'meminfo')).replace('/proc/sys/kernel/random/boot_id',str(remote/'boot-id'))

    result=subprocess.run(['bash','-c',c],capture_output=True,text=True,check=False)
    sys.stdout.write(result.stdout.replace(str(remote),''));sys.stderr.write(result.stderr.replace(str(remote),''))
    sys.exit(result.returncode)
'''
SCP = r'''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys, time
cfg=json.loads(pathlib.Path(os.environ['PHI_FIXTURE']).read_text())
args=[];i=1
while i<len(sys.argv):
    v=sys.argv[i]
    if v in ('-o','-i'): i+=2;continue
    if v in ('-r','-O'): i+=1;continue
    args.append(v);i+=1
def mapped(p): return pathlib.Path(cfg['remote'])/p.split(':',1)[1].lstrip('/')
if args[0].startswith('root@'):
    if mapped(args[0]).is_dir(): shutil.copytree(mapped(args[0]),args[1])
    else: shutil.copy2(mapped(args[0]),args[1])
else:
    dest=mapped(args[-1])
    if cfg.get('fail_upload') and str(dest).endswith('.part'):
        dest.write_bytes(b'partial');print('fixture interrupted upload',file=sys.stderr);sys.exit(1)
    for src in args[:-1]:
        target=dest/pathlib.Path(src).name if dest.is_dir() else dest
        if cfg.get('slow_upload') and str(target).endswith('.part'):
            with open(src,'rb') as inp, target.open('wb') as out:
                while block:=inp.read(64):
                    out.write(block);out.flush();time.sleep(0.3)
        else:
            shutil.copy2(src,target)
            if pathlib.Path(src).name=='model-cache.sh':
                # Test platform/path boundaries only; real cache policy executes.
                text=target.read_text().replace('[[ $(uname -m) == k1om ]]','[[ fixture == fixture ]]')
                text=text.replace('/proc/',cfg['remote']+'/proc/')
                text=text.replace('/root/',cfg['remote']+'/root/').replace('/tmp/knc-phase3-workload.lock',cfg['remote']+'/tmp/knc-phase3-workload.lock')
                target.write_text(text)


'''


def setup_app(tmp_path: Path, sku: str = '3120a') -> dict[str, Any]:
    app = tmp_path / 'PhiChat fixture' / 'app'
    shutil.copytree(ROOT, app, ignore=shutil.ignore_patterns('__pycache__', '.pytest_cache'))
    data=app/'data'; data.mkdir()
    kit=tmp_path/'kit'; (kit/'artifacts').mkdir(parents=True)
    cfg=json.loads((app/'config/app.yaml').read_text())
    project=app.parent
    (project/'models').mkdir()
    models={}
    template=json.loads((app/'config/models/tinydolphin-q5_k_m.yaml').read_text())
    for index,name in enumerate(['fixture-small','fixture-medium','fixture-large','fixture-extra']):
        profile=dict(template,id=name,label='Synthetic '+name,filename=name+'.gguf',
                     estimated_peak_runtime_mib=1024 if index==0 else 1536,minimum_memory_mib=3072,
                     chat_template='zephyr' if index==0 else 'chatml')
        (app/'config/models'/f'{name}.yaml').write_text(json.dumps(profile))
    def gguf_string(value):
        value=value.encode();return struct.pack('<Q',len(value))+value
    def metadata_bytes(architecture,identity):
        values={'general.architecture':architecture,'general.name':identity,
                architecture+'.context_length':4096,architecture+'.block_count':22,
                architecture+'.embedding_length':2048,architecture+'.attention.head_count':32,
                architecture+'.attention.head_count_kv':4}
        data=b'GGUF'+struct.pack('<IQQ',3,0,len(values))
        for key,value in values.items():
            data+=gguf_string(key)+struct.pack('<I',8 if isinstance(value,str) else 4)
            data+=gguf_string(value) if isinstance(value,str) else struct.pack('<I',value)
        return data
    for file in (app/'config/models').glob('*.yaml'):
        model=json.loads(file.read_text())
        content=metadata_bytes(model['architecture'],file.name)
        model['file_size_bytes']=len(content)
        model['sha256']=hashlib.sha256(content).hexdigest()
        file.write_text(json.dumps(model))
        (project/'models'/model['filename']).write_bytes(content)
        models[file.stem]=model
    mic_text=(ROOT/'tests/fixtures/micinfo-windows-3120a.txt').read_text()
    lines=[line for line in mic_text.splitlines() if 'Device Serial Number' not in line]
    mic_text='\n'.join(lines)+'\nDevice Serial Number : TEST-CARD\n'
    if sku=='7120p':
        mic_text=mic_text.replace('57','61').replace('5952','15872').replace('3120/3140 P/A','7120 P').replace('Product 300W Active CS','Product 300W Passive')
    bindir=tmp_path/'bin'; bindir.mkdir()
    mic_source='''#!/usr/bin/env python3
import json, os, pathlib, re, sys
cfg=json.loads(pathlib.Path(os.environ['PHI_FIXTURE']).read_text())
remote=pathlib.Path(cfg['remote'])
text=MIC_TEXT
temperature=cfg.get('temperature',41)
if (remote/'inference-running').exists():
    if cfg.get('lost_telemetry_during_inference'): sys.exit(1)
    temperature=cfg.get('temperature_during_inference',temperature)
if any(p.stat().st_size for p in remote.rglob('*.part')):
    temperature=cfg.get('temperature_during_transfer',temperature)
text=re.sub(r'(?m)^(\\s*Die Temp\\s*:\\s*).+$',lambda m:m[1]+str(temperature)+' C',text)
if cfg.get('stopped_fan'): text=re.sub(r'(?m)^(\\s*Fan RPM\\s*:\\s*).+$',lambda m:m[1]+'0',text)
print(text)
'''.replace('MIC_TEXT',repr(mic_text))
    for name,source in [('ssh.exe',SSH),('scp.exe',SCP),('micinfo.exe',mic_source)]:
        path=bindir/name;path.write_text(source);path.chmod(0o755)
    key=tmp_path/'fixture-key'; key.write_text('not a key; fake executables only')
    connection=dict(project_dir=str(project),phase3_kit=str(kit),data_dir=str(data),card_address='fixture.invalid',key_path=str(key),micinfo=str(bindir/'micinfo.exe'))
    (app/'config/connection.yaml').write_text(json.dumps(connection))
    remote=tmp_path/'remote'; (remote/'tmp').mkdir(parents=True)
    runtime=remote/'root/knc-phase3-run-fixture'; (runtime/'llama').mkdir(parents=True)
    (runtime/'build-passed.txt').write_text(cfg['source_commit'])
    for p in [runtime/'guard',runtime/'llama/main']: p.write_text('fixture');p.chmod(0o755)
    shutil.copy2(project/'models'/models['fixture-small']['filename'],runtime/'model.gguf')
    state=dict(source_commit=cfg['source_commit'],remote_base='/root/knc-phase3-run-fixture',model_sha256=models['fixture-small']['sha256'])
    (kit/'artifacts/last-build.json').write_text(json.dumps(state))
    fixture=tmp_path/'fixture.json'; fixture.write_text(json.dumps(dict(remote=str(remote),sku=sku,free_kib=15000000 if sku=='7120p' else 5500000)))
    env=dict(os.environ,PATH=str(bindir)+os.pathsep+os.environ['PATH'],PHI_FIXTURE=str(fixture))
    return dict(app=app,data=data,project=project,remote=remote,runtime=runtime,fixture=fixture,env=env,models=models)


def change_fixture(f: dict[str, Any], **values: Any) -> None:
    config=json.loads(f['fixture'].read_text());config.update(values);f['fixture'].write_text(json.dumps(config))


def run_job(f: dict[str, Any], name: str, model: str = 'fixture-small', **fields: Any) -> tuple[subprocess.CompletedProcess[str], dict[str, Any], Path]:
    job=f['data']/'jobs'/name; job.mkdir(parents=True)
    request=dict(action='Chat',model=model,batch=32,owner_pid=0,output_tokens=128,connected_serial='TEST-CARD',messages=[dict(role='user',content='test question')],ready=f.get('ready'))
    request.update(fields)
    (job/'request.json').write_text(json.dumps(request))
    result=subprocess.run([str(PWSH),'-NoProfile','-File',str(f['app']/'Invoke-PhiJob.ps1'),'-JobDir',str(job)],env=f['env'],capture_output=True,text=True,timeout=40,check=False)
    status=json.loads((job/'status.json').read_text())
    if request['action']=='Load': f['ready']=status.get('result') if status['state']=='done' else None
    return result,status,job


def load_model(f: dict[str, Any], name: str, model: str = 'fixture-small') -> tuple[dict[str, Any], Path]:
    result,status,job=run_job(f,name,model,action='Load',messages=[])
    assert result.returncode==0,(result.stdout,result.stderr,status)
    assert status['state']=='done' and status['progress']['percent']==100
    assert status['result']['model_id']==f['models'][model]['id']
    assert not (job/'response.txt').exists()
    assert not (job/'generation').exists()
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()
    assert not list(f['remote'].rglob('prompt.txt'))
    return status,job


def assert_chat_ok(result: subprocess.CompletedProcess[str], status: dict[str, Any], job: Path, f: dict[str, Any], threads: int = 224) -> None:
    assert result.returncode==0,(result.stdout,result.stderr,status)
    assert status['state']=='done'
    assert status['result']['generation_threads']==threads
    assert status['result']['prompt_threads']==threads
    assert 'café' in (job/'response.txt').read_text()
    assert not (job/'request.json').exists()
    assert not list(f['remote'].rglob('prompt.txt'))
    assert not list(job.rglob('prompt.txt'))
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()
    assert not (f['data']/'accepted').exists()
    assert 'wc -c' not in (f['remote']/'commands.txt').read_text(), 'Model size checks must use metadata'
    assert (job/'forecast.json').exists()


def test_direct_chat_and_model_switching_without_any_acceptance_record(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    # Old rejected import records must not block this release or be altered.
    obsolete=f['data']/'evidence-import.json';obsolete.write_text('{"accepted":false}')
    unrelated=f['runtime']/'keep-report.txt';unrelated.write_text('historical measurements')
    for index,name in enumerate(['fixture-small','fixture-medium','fixture-small']):
        load_model(f,'load-'+str(index),name)
        result,status,job=run_job(f,str(index),name)
        assert_chat_ok(result,status,job,f)
        assert status['result']['generation_tps']==100
        assert status['result']['model_id']==f['models'][name]['id']
        assert unrelated.read_text()=='historical measurements'
        assert obsolete.read_text()=='{"accepted":false}'
        assert all((f['project']/'models'/m['filename']).exists() for m in f['models'].values())
        assert len(list(f['runtime'].rglob('*.gguf')))==1
    assert not (f['runtime']/'model.gguf').exists()


def test_model_without_windows_backup_is_saved_before_eviction(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    (f['project']/'models'/f['models']['fixture-small']['filename']).unlink()
    load_model(f,'prepare-phi2','fixture-medium')
    result,status,job=run_job(f,'phi2','fixture-medium')
    assert_chat_ok(result,status,job,f)
    assert not (f['runtime']/'model.gguf').exists()
    assert (f['project']/'models'/f['models']['fixture-small']['filename']).exists()


def test_7120p_enables_larger_model_with_same_worker(tmp_path: Path) -> None:
    f=setup_app(tmp_path,'7120p')
    load_model(f,'prepare-q4','fixture-large')
    result,status,job=run_job(f,'q4','fixture-large')
    assert_chat_ok(result,status,job,f,240)


@pytest.mark.parametrize('failure', ['budget','temperature','stopped_fan','missing_temperature','wrong_card','architecture','free_memory','native_crash','upload','busy'])
def test_actual_failures_remain_visible_and_do_not_fallback(tmp_path: Path, failure: str) -> None:
    f=setup_app(tmp_path); model='fixture-small'; fields={}
    expected={'budget':'safe budget','temperature':'75 C limit','stopped_fan':'positive fan RPM','missing_temperature':'Die Temp','wrong_card':'connected card changed','architecture':'not K1OM','free_memory':'Insufficient allocatable GDDR','native_crash':'fixture native runtime error','upload':'fixture interrupted upload','busy':'Another workload'}[failure]
    if failure=='budget':
        profile=f['app']/'config/models/fixture-small.yaml'
        m=json.loads(profile.read_text());m['minimum_memory_mib']=8192;profile.write_text(json.dumps(m))
    if failure=='temperature': change_fixture(f,temperature=75)
    if failure=='stopped_fan': change_fixture(f,stopped_fan=True)
    if failure=='missing_temperature': change_fixture(f,temperature='N/A')
    if failure=='wrong_card': fields['connected_serial']='OTHER-CARD'
    if failure=='architecture': change_fixture(f,architecture='x86_64')
    if failure=='free_memory': model='fixture-medium'; change_fixture(f,free_kib=1000000)
    if failure=='native_crash': change_fixture(f,inference_exit=139)
    if failure=='upload': model='fixture-medium';change_fixture(f,fail_upload=True)
    lock=f['remote']/'tmp/knc-phase3-workload.lock'
    if failure=='busy': lock.mkdir();(lock/'phi-chat-owner').write_text('another-job')
    if failure=='native_crash': load_model(f,'prepare-crash',model)
    fields['action']='Chat' if failure=='native_crash' else 'Load'
    result,status,job=run_job(f,'failed',model,**fields)
    assert result.returncode!=0,(result.stdout,result.stderr,status)
    assert status['state']=='failed'
    assert expected in status['message'],status
    assert not (job/'request.json').exists()
    assert not list(f['runtime'].rglob('*.part'))
    if failure=='busy': assert (lock/'phi-chat-owner').read_text()=='another-job'
    else: assert not lock.exists()
    if failure not in ['native_crash']:
        commands=f['remote']/'commands.txt'
        assert not commands.exists() or not any(line.startswith('exec ') for line in commands.read_text().splitlines())


def test_successful_short_answer_does_not_require_speed_measurement(tmp_path: Path) -> None:
    f=setup_app(tmp_path);change_fixture(f,no_timing=True)
    load_model(f,'prepare-short')
    result,status,job=run_job(f,'short')
    assert_chat_ok(result,status,job,f)
    assert status['result']['generation_tps'] is None
    assert 'speed unavailable' in status['message']


def test_connect_is_independent_of_selected_model_budget(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    result,status,job=run_job(f,'health','fixture-large',action='Health')
    assert result.returncode==0,(result.stdout,result.stderr,status)
    assert status['state']=='done' and 'Connected:' in status['message']
    assert (job/'hardware.json').exists()
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()


def test_send_without_load_never_downloads_or_transfers_weights(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    for model in f['models'].values(): (f['project']/'models'/model['filename']).unlink()
    result,status,job=run_job(f,'unprepared','fixture-medium')
    assert result.returncode!=0
    assert 'Click Load model' in status['message']
    assert not list(f['project'].rglob('*.part'))
    assert not (f['runtime']/'models').exists()
    assert not (job/'load-progress.jsonl').exists()


def test_card_copy_used_without_windows_file_during_chat(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    load_model(f,'prepare')
    (f['project']/'models'/f['models']['fixture-small']['filename']).unlink()
    result,status,job=run_job(f,'chat')
    assert_chat_ok(result,status,job,f)
    assert not (job/'load-progress.jsonl').exists()


@pytest.mark.parametrize('change',['missing_card_copy','selected_model','serial'])
def test_stale_ready_state_cannot_start_chat(tmp_path: Path, change: str) -> None:
    f=setup_app(tmp_path)
    load_model(f,'prepare')
    model='fixture-small'
    if change=='missing_card_copy': (f['runtime']/'model.gguf').unlink()
    if change=='selected_model': model='fixture-medium'
    if change=='serial': f['ready']['serial']='OLD-CARD'
    result,status,job=run_job(f,'stale',model)
    assert result.returncode!=0
    assert 'Click Load model' in status['message']
    assert not (job/'load-progress.jsonl').exists()
    assert not any(line.startswith('exec ') for line in (f['remote']/'commands.txt').read_text().splitlines())


def test_transfer_progress_reports_actual_partial_bytes(tmp_path: Path) -> None:
    f=setup_app(tmp_path);change_fixture(f,slow_upload=True)
    status,job=load_model(f,'progress','fixture-medium')
    rows=[json.loads(line) for line in (job/'load-progress.jsonl').read_text().splitlines()]
    assert all(row['stage']=='Copying to Xeon Phi' for row in rows)
    assert any(0<row['bytes']<row['total_bytes'] and 0<row['percent']<100 for row in rows),rows
    assert rows[-1]['percent']==100
    assert rows[-1]['bytes']==f['models']['fixture-medium']['file_size_bytes']
    assert status['message'].startswith('Ready on Xeon Phi:')


def test_cancelled_load_cleans_transfer_without_ready(tmp_path: Path) -> None:
    import threading
    import time

    f=setup_app(tmp_path);change_fixture(f,slow_upload=True)
    job=f['data']/'jobs/cancelled-load'
    observed=[]

    def cancel_after_bytes() -> None:
        deadline=time.monotonic()+12
        while time.monotonic()<deadline:
            progress=job/'load-progress.jsonl'
            if progress.exists():
                for line in progress.read_text().splitlines():
                    try: row=json.loads(line)
                    except json.JSONDecodeError: continue
                    if row['bytes']>0:
                        (job/'cancel').write_text('stop');observed.append(True);return
            time.sleep(0.05)

    thread=threading.Thread(target=cancel_after_bytes,daemon=True);thread.start()
    result,status,job=run_job(f,'cancelled-load','fixture-medium',action='Load',messages=[])
    thread.join(timeout=13)
    assert observed,'No transfer progress reached the cancellation fixture'
    assert result.returncode!=0 and status['state']=='failed'
    assert 'Stopped by operator' in status['message']
    assert f['ready'] is None
    assert not (job/'ready.json').exists()
    assert not list(f['runtime'].rglob('*.part'))
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()
    assert all((f['project']/'models'/m['filename']).exists() for m in f['models'].values())


@pytest.mark.parametrize('fault',['overheat','lost_telemetry'])
def test_temperature_monitor_stops_running_chat_and_closes_heartbeat(tmp_path: Path, fault: str) -> None:
    f=setup_app(tmp_path)
    load_model(f,'load')
    change_fixture(f,slow_inference=True,temperature_during_inference=85 if fault=='overheat' else 41,
                   lost_telemetry_during_inference=fault=='lost_telemetry')
    result,status,job=run_job(f,'thermal-stop')
    assert result.returncode!=0 and status['state']=='failed'
    assert ('85 C' if fault=='overheat' else 'exit') in status['message'],status
    assert (f['remote']/'inference-stopped').exists(),'monitor must close guard input'
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()


def test_temperature_monitor_stops_model_copy(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    cfg_path=f['app']/'config/app.yaml'
    cfg=json.loads(cfg_path.read_text());cfg['poll_seconds']=1;cfg_path.write_text(json.dumps(cfg))
    change_fixture(f,slow_upload=True,temperature_during_transfer=85)
    result,status,job=run_job(f,'hot-transfer','fixture-medium',action='Load')
    assert result.returncode!=0 and '85 C' in status['message'],status
    assert not (job/'ready.json').exists()
    assert not list(f['runtime'].rglob('*.part'))
    assert not (f['remote']/'tmp/knc-phase3-workload.lock').exists()


def test_missing_manual_confirmation_does_not_block_healthy_card(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    result,status,job=run_job(f,'no-checkbox',action='Load',cooling_confirmed=False)
    assert result.returncode==0,(result.stdout,result.stderr,status)
    assert status['state']=='done'
    assert not (job/'cooling-confirmation.txt').exists()
    assert (job/'telemetry.csv').exists()


def test_runtime_memory_is_rechecked_before_each_answer(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    load_model(f,'load')
    change_fixture(f,free_kib=100000)
    result,status,job=run_job(f,'low-memory-chat')
    assert result.returncode!=0 and 'Short by' in status['message']
    assert not any(line.startswith('exec ') for line in (f['remote']/'commands.txt').read_text().splitlines())


def test_unconfirmed_mapping_is_not_reported_as_success(tmp_path: Path) -> None:
    f=setup_app(tmp_path)
    load_model(f,'load')
    change_fixture(f,missing_mapping=True)
    result,status,job=run_job(f,'no-mmap')
    assert result.returncode != 0
    assert 'mapping was not confirmed' in status['message']


@pytest.mark.parametrize('model', ['tinydolphin-q5_k_m', 'fixture-extra'])
def test_q5_model_load_and_chat_on_3120a_fixture(tmp_path: Path, model: str) -> None:
    f=setup_app(tmp_path)
    load_model(f,'load-q5',model)
    result,status,job=run_job(f,'q5-chat',model)
    assert_chat_ok(result,status,job,f)
    assert status['result']['memory_mode']=='shared_mmap'
    assert status['result']['peak_additional_rss_mib'] < status['result']['peak_rss_mib']
    assert status['result']['first_byte_seconds'] is not None
