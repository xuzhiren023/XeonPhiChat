"""Real model-switch policy with small files and explicit fake MPSS/SSH only."""
from pathlib import Path
import json
import shutil
import pytest
from test_job_fixture import setup_app, run_job, load_model


def put_model(f, root, name, *, identity=True, baseline=False, part=False):
    root.mkdir(parents=True, exist_ok=True)
    pin=json.loads((f['app']/'config/app.yaml').read_text())['source_commit']
    (root/'build-passed.txt').write_text(pin)
    model=f['models'][name]
    path=root/'model.gguf' if baseline else root/'models'/(model['id']+'.gguf'+('.part' if part else ''))
    path.parent.mkdir(exist_ok=True)
    shutil.copy2(f['project']/'models'/model['filename'], path)
    if part: path.write_bytes(path.read_bytes()[:15])
    if identity: Path(str(path)+'.identity').write_text(model['sha256']+'\n')
    return path


def test_old_runtime_alias_duplicate_partial_and_unknown_files(tmp_path):
    f=setup_app(tmp_path)
    old=f['remote']/'root/knc-phase3-run-old'
    dolphin=put_model(f,old,'tinydolphin-q5_k_m')
    alias=put_model(f,old,'fixture-small',identity=False,baseline=True)
    duplicate=put_model(f,old,'fixture-extra')
    partial=put_model(f,old,'fixture-large',identity=False,part=True)
    unknown=old/'models/private-model.gguf';unknown.write_bytes(b'unrecognized, preserve')
    report=old/'benchmark.txt';report.write_text('historical baseline')
    unrelated=f['remote']/'root/knc-phase3-run-unmanaged'
    untouched=put_model(f,unrelated,'tinydolphin-q5_k_m')
    (unrelated/'build-passed.txt').write_text('f'*40)
    status,job=load_model(f,'switch','fixture-extra')
    assert all(not p.exists() for p in (dolphin,alias,duplicate,partial,f['runtime']/'model.gguf'))
    assert unknown.read_bytes()==b'unrecognized, preserve'
    assert report.read_text()=='historical baseline' and untouched.exists()
    assert 'Retained 1 unrecognized' in status['message']
    audit=json.loads((job/'cache-cleanup.json').read_text())
    assert audit['removed_files']==5 and audit['removed_file_bytes']>0
    assert audit['before']['available_kib']==audit['after']['available_kib'], 'Fixture cannot invent reclaimed real RAM'
    assert len(list(f['runtime'].rglob('*.gguf')))==1
    assert all((f['project']/'models'/m['filename']).exists() for m in f['models'].values())
    assert not list((f['project']/'models').glob('*.part'))


def test_duplicate_selected_weights_current_alias_removed(tmp_path):
    f=setup_app(tmp_path)
    selected=put_model(f,f['runtime'],'fixture-small')
    status,job=load_model(f,'same')
    assert selected.exists() and not (f['runtime']/'model.gguf').exists()
    assert json.loads((job/'cache-cleanup.json').read_text())['removed_files']==1
    assert status['result']['remote_model'].endswith('/models/'+f['models']['fixture-small']['id']+'.gguf')


def test_only_corrupted_copy_is_not_destroyed(tmp_path):
    f=setup_app(tmp_path)
    backup=f['project']/'models'/f['models']['fixture-small']['filename'];backup.unlink()
    path=f['runtime']/'model.gguf';raw=path.read_bytes();path.write_bytes(raw[:-1]+b'!')
    result,status,job=run_job(f,'corrupt','fixture-extra',action='Load',messages=[])
    assert result.returncode!=0 and 'pinned SHA-256' in status['message']
    assert path.exists() and not backup.exists()
    assert not list((f['project']/'models').glob('*.part'))
    assert json.loads((job/'cache-cleanup.json').read_text())['removed_files']==0


@pytest.mark.parametrize('kind',['maps','fd'])
def test_open_or_mapped_model_blocks_eviction(tmp_path,kind):
    f=setup_app(tmp_path)
    proc=f['remote']/'proc/123';proc.mkdir(parents=True)
    path=f['runtime']/'model.gguf'
    if kind=='maps': (proc/'maps').write_text(f'1000-2000 r--s 0 00:00 1 {path}\n')
    else:
        (proc/'fd').mkdir();(proc/'fd/8').symlink_to(path)
    result,status,job=run_job(f,'busy-model','fixture-extra',action='Load',messages=[])
    assert result.returncode!=0 and 'stop that workload first' in status['message']
    assert path.exists()
    assert not list((f['runtime']/'models').glob('*.gguf'))


def test_foreign_identity_at_selected_path_is_preserved(tmp_path):
    f=setup_app(tmp_path)
    path=put_model(f,f['runtime'],'fixture-extra')
    Path(str(path)+'.identity').write_text('e'*64)
    data=path.read_bytes()
    result,status,job=run_job(f,'conflict','fixture-extra',action='Load',messages=[])
    assert result.returncode!=0 and 'different model identity' in status['message']
    assert path.read_bytes()==data


def test_symlinked_cache_is_not_followed(tmp_path):
    f=setup_app(tmp_path)
    old=f['remote']/'root/knc-phase3-run-linked';old.mkdir()
    (old/'build-passed.txt').write_bytes((f['runtime']/'build-passed.txt').read_bytes())
    outside=f['remote']/'precious';outside.mkdir()
    sentinel=outside/(f['models']['tinydolphin-q5_k_m']['id']+'.gguf')
    sentinel.write_text('unrelated')
    (old/'models').symlink_to(outside,target_is_directory=True)
    load_model(f,'switch','fixture-extra')
    assert sentinel.read_text()=='unrelated'
