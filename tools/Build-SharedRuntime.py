#!/usr/bin/env python3
"""Developer-only: compose pinned KNC builds with Phi Chat's existing guard suite.

Python 3.8+, no third-party packages. End users consume the Windows release ZIP.
This packages binaries; it never executes them or writes native acceptance.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import shutil
import struct
import tarfile

ROOT = Path(__file__).resolve().parent.parent
SOURCE = '6783b11fb0889d68d0046176b4cc92ceee1961b0'
GOMP = '89e7a6b598a2264d804e47aff046a452695f263bfd0cebdaaa38ac8959dcc331'
BUILDS = {
    '3120A': {
        'candidate': 'knc-mq-dc2cee6d8fb2420e1a06',
        'revision': 'r3', 'native_evidence': 'cross-build and ISA audit only; native validation pending',
        'hashes': ['a8ff7cda62fdb384ed02f1f36e7a96dd43df5209ca2992eef45dc088d9446883',
                   '2b531fd85a504ad11efa28c5e1560fe14886252834105ce54cc67cdf39f24520',
                   'd56ec5171b717849fe048309b2511d146c90aab8572230df0119c024a7c9b4f3'],
    },
    '7120P': {
        'candidate': 'knc-mq-a3ab0be8c35cb872acb6',
        'revision': 'standalone-export-r4',
        'native_evidence': 'upstream export: operators/graphs passed; TinyDolphin Q5_K_M bitwise comparison with qualified r3 at rows8, prompt120/decode180; not app integration acceptance',
        'hashes': ['3bda6cddfe8c7cd976348bb244a42e3b0610894a63364366e5391eb300f87453',
                   '4c1eada449c8b307c4f6351d3f5a6341487d6309487135e508c2f651c0d0d95e',
                   'ff018d83ed45c3c9705eed0a1dc9c049d68216d2b72d0bbe8013929ae8ea128f'],
    },
}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True)+'\n').encode('utf-8')

def verified(path, sha, size=None, elf=False):
    data = path.read_bytes()
    if digest(data) != sha or (size is not None and len(data) != size):
        raise ValueError('Pinned input changed: '+str(path))
    if elf and (data[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<H', data, 18)[0] != 181):
        raise ValueError('Expected native K1OM ELF: '+str(path))
    return data

def compose(profile, build, base_dir, output, gomp, old_pin):
    info = BUILDS[profile]
    base = next(p for p in old_pin['payloads'] if p['profile'] == 'xeon-phi-'+profile.lower())
    receipt = read_json(build/'CANDIDATE-BUILD.json')
    if receipt['candidate_id'] != info['candidate'] or receipt['profile'] != profile:
        raise ValueError('Candidate/profile mismatch')
    base_bytes = verified(base_dir/base['file'], base['sha256'], base['bytes'])
    files, modes = {}, {}
    with tarfile.open(fileobj=io.BytesIO(base_bytes), mode='r:') as tf:
        for member in tf:
            name = member.name.removeprefix('./') if hasattr(str, 'removeprefix') else member.name[2:] if member.name.startswith('./') else member.name
            path = PurePosixPath(name)
            if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name or not (member.isfile() or member.isdir()):
                raise ValueError('Unsafe base archive member: '+name)
            if member.isdir():
                continue
            if name in files:
                raise ValueError('Duplicate archive member: '+name)
            if name.startswith('optimized/') or name in ('optimized-runtime-id.txt', 'modern-runtime-passed.txt', 'build-passed.txt'):
                continue
            files[name] = tf.extractfile(member).read()
            modes[name] = member.mode & 0o777
    if files['runtime-id.txt'].decode().strip() != base['runtime_id']:
        raise ValueError('Base runtime identity mismatch')
    if files['modern-source.txt'].decode().strip() != SOURCE:
        raise ValueError('Modern source mismatch')
    native = {}
    for name, sha in zip(('phi-modern', 'test-knc-mq', 'test-modern-ops'), info['hashes']):
        entry = receipt['binaries'][name]
        if entry['sha256'] != sha:
            raise ValueError('Audit binary pin mismatch')
        data = verified(build/name, sha, entry['bytes'], elf=True)
        files['shared/bin/'+name] = data
        modes['shared/bin/'+name] = 0o700
        native[name] = {'sha256': sha, 'bytes': len(data)}
    files['shared/lib/libgomp.so.1'] = verified(gomp, GOMP, elf=True)
    modes['shared/lib/libgomp.so.1'] = 0o700
    for src, dst in (('shared-knc-env.sh', 'configure.sh'), ('shared-knc-affinity.awk', 'knc-affinity.awk')):
        files['shared/'+dst] = (ROOT/'app/scripts'/src).read_bytes().replace(b'\r\n', b'\n')
        modes['shared/'+dst] = 0o600
    identity_inputs = {'base_sha256': base['sha256'], 'files': {n: digest(b) for n, b in sorted(files.items()) if n.startswith('shared/')}}
    identity = 'phichat142-modern-'+digest(json_bytes(identity_inputs))[:16]
    provenance = dict(info, source_commit=SOURCE, profile=base['profile'], runtime_id=identity,
                      parent_runtime_id=base['runtime_id'], parent_sha256=base['sha256'], binaries=native,
                      libgomp_sha256=GOMP, native_acceptance=False,
                      build_receipt_sha256=digest((build/'CANDIDATE-BUILD.json').read_bytes()))
    del provenance['hashes']
    files['shared/provenance.json'] = json_bytes(provenance)
    files['parent-runtime-id.txt'] = (base['runtime_id']+'\n').encode()
    for name in ('runtime-id.txt', 'shared-runtime-id.txt'):
        files[name] = (identity+'\n').encode()
    target = output/base['file']
    if target.exists():
        raise ValueError('Preserve existing output: '+str(target))
    with tarfile.open(target, 'x', format=tarfile.USTAR_FORMAT) as tf:
        for name, data in sorted(files.items()):
            m = tarfile.TarInfo(name)
            m.size, m.mode = len(data), modes.get(name, 0o600)
            tf.addfile(m, io.BytesIO(data))
    # Verify every packaged byte and ensure no inherited acceptance was shipped.
    with tarfile.open(target) as tf:
        members = tf.getmembers()
        if len(members) != len(files):
            raise ValueError('Archive count mismatch')
        for m in members:
            if tf.extractfile(m).read() != files[m.name]:
                raise ValueError('Archive content mismatch')
        assert not any(m.name in ('build-passed.txt', 'modern-runtime-passed.txt') for m in members)
    payload = dict(profile=base['profile'], file=base['file'], sha256=digest(target.read_bytes()),
                   bytes=target.stat().st_size, runtime_id=identity, main_sha256=info['hashes'][0],
                   features=['auto-resources-v1', 'shared-multi-quant-v1'])
    return payload, provenance

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base-assets', type=Path, required=True)
    p.add_argument('--build-3120a', type=Path, required=True)
    p.add_argument('--build-7120p', type=Path, required=True)
    p.add_argument('--libgomp', type=Path, required=True)
    a = p.parse_args()
    output = ROOT/'assets/payloads'
    output.mkdir(parents=True, exist_ok=True)
    old = read_json(ROOT/'app/config/modern-runtime-1.5.3-paired.json')
    pins, evidence = [], []
    for profile, build in (('3120A', a.build_3120a), ('7120P', a.build_7120p)):
        pin, ev = compose(profile, build, a.base_assets, output, a.libgomp, old)
        pins.append(pin); evidence.append(ev)
    old['payloads'] = pins
    old['repair_version'] = 'shared-multi-quant-v1'
    manifest = read_json(ROOT/'assets/runtime-manifest.json')
    backup = next(x for x in manifest['assets'] if x['kind'] == 'guard-backup')
    verified(a.base_assets/backup['file'], backup['sha256'], backup['bytes'])
    target = output/backup['file']
    if target.exists():
        raise ValueError('Preserve existing backup output')
    shutil.copyfile(a.base_assets/backup['file'], target)
    manifest.pop('native_payloads_unchanged_from', None)
    manifest['version'] = (ROOT/'VERSION').read_text().strip()
    manifest['assets'] = [dict((k,v) for k,v in pin.items() if k not in ('main_sha256','features')) for pin in pins]
    for asset in manifest['assets']: asset['kind'] = 'modern'
    manifest['assets'].append(backup)
    (ROOT/'app/config/modern-runtime.json').write_bytes(json_bytes(old))
    (ROOT/'assets/runtime-manifest.json').write_bytes(json_bytes(manifest))
    (ROOT/'docs/shared-runtime-provenance.json').write_bytes(json_bytes(evidence))
    print(json.dumps(pins, indent=2))

if __name__ == '__main__':
    main()
