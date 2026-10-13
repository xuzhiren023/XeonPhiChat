#!/usr/bin/env python3
"""Compose PhiChat's d57e0e6 payloads from pinned offline build evidence.

Developer tool only; Python 3.8+, no compiler or hardware access.
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
SOURCE = 'd57e0e6e4882445bc625aaee47f91db469f9fc22'
BASE_SOURCE = '6783b11fb0889d68d0046176b4cc92ceee1961b0'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def verified(data, pin, elf=False):
    if digest(data) != pin['sha256'] or len(data) != pin['bytes']:
        raise ValueError('Pinned input bytes changed')
    if elf and (data[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<H', data, 18)[0] != 181):
        raise ValueError('Expected native K1OM ELF')
    return data


def compose(profile, archive, base_dir, output, build_pin, parent):
    files, modes = {}, {}
    base_bytes = verified((base_dir / parent['file']).read_bytes(), parent)
    with tarfile.open(fileobj=io.BytesIO(base_bytes), mode='r:') as base:
        for member in base:
            name = member.name[2:] if member.name.startswith('./') else member.name
            path = PurePosixPath(name)
            if path.is_absolute() or '..' in path.parts or '\\' in name or ':' in name or not (member.isfile() or member.isdir()):
                raise ValueError('Unsafe base member: ' + name)
            if member.isdir():
                continue
            if name in files:
                raise ValueError('Duplicate base member: ' + name)
            if name.startswith(('optimized/', 'shared/')) or name in ('optimized-runtime-id.txt', 'modern-runtime-passed.txt', 'build-passed.txt'):
                continue
            files[name] = base.extractfile(member).read()
            modes[name] = member.mode & 0o777
    if files['runtime-id.txt'].decode().strip() != parent['runtime_id'] or files['modern-source.txt'].decode().strip() != BASE_SOURCE:
        raise ValueError('Parent runtime identity changed')
    binaries = {}
    for pin in build_pin['profiles'][profile]['files']:
        path = pin['file']
        if path not in ('bin/phi-modern', 'bin/test-knc-dot', 'bin/test-knc-mq', 'bin/test-backend-ops', 'bin/test-quantize-fns', 'bin/test-sampling', 'lib/libgomp.so.1'):
            raise ValueError('Unexpected build input: ' + path)
        member = archive.getmember('knc-upstream-artifacts/' + profile + '/' + path)
        if not member.isfile():
            raise ValueError('Build input is not a regular file')
        data = verified(archive.extractfile(member).read(), pin, elf=True)
        if path.startswith('bin/') and b'$ORIGIN/../lib' not in data:
            raise ValueError('Private library runpath missing')
        files['shared/' + path] = data
        modes['shared/' + path] = 0o700
        if path.startswith('bin/'):
            binaries[path[4:]] = {'sha256': pin['sha256'], 'bytes': pin['bytes']}
    if len(binaries) != 6:
        raise ValueError('Incomplete native test/runner set')
    for src, dst in [('shared-knc-env.sh', 'configure.sh'), ('shared-knc-affinity.awk', 'knc-affinity.awk')]:
        files['shared/' + dst] = (ROOT / 'app/scripts' / src).read_bytes().replace(b'\r\n', b'\n')
    identity_inputs = {'source_commit': SOURCE, 'base_sha256': parent['sha256'],
                       'files': {n: digest(b) for n, b in sorted(files.items()) if n.startswith('shared/')}}
    identity = 'phichat142-modern-' + digest(json_bytes(identity_inputs))[:16]
    provenance = {'source_commit': SOURCE, 'upstream_base': build_pin['upstream_base'], 'profile': parent['profile'],
                  'retained_standard_source_commit': BASE_SOURCE,
                  'retained_legacy_source_commit': '03a8b80c7d502797325788f604248dd4aabdf5ef',
                  'runtime_id': identity, 'parent_runtime_id': parent['runtime_id'], 'parent_sha256': parent['sha256'],
                  'artifact_archive_sha256': build_pin['artifact_archive_sha256'], 'binaries': binaries,
                  'libgomp_sha256': digest(files['shared/lib/libgomp.so.1']), 'driver_files': build_pin['driver_files'],
                  'compiler': build_pin['compiler'], 'native_acceptance': False,
                  'native_evidence': 'Host checks and cross-build/ISA audit only; native validation and speed pending.'}
    files['shared/provenance.json'] = json_bytes(provenance)
    files['parent-runtime-id.txt'] = (parent['runtime_id'] + '\n').encode()
    files['modern-source.txt'] = (SOURCE + '\n').encode()
    files['retained-standard-source.txt'] = (BASE_SOURCE + '\n').encode()
    for name in ('runtime-id.txt', 'shared-runtime-id.txt'):
        files[name] = (identity + '\n').encode()
    target = output / parent['file']
    with tarfile.open(target, 'x', format=tarfile.USTAR_FORMAT) as result:
        for name, data in sorted(files.items()):
            member = tarfile.TarInfo(name)
            member.size, member.mode = len(data), modes.get(name, 0o600)
            result.addfile(member, io.BytesIO(data))
    with tarfile.open(target) as result:
        if len(result.getmembers()) != len(files):
            raise ValueError('Archive count mismatch')
        for member in result:
            if result.extractfile(member).read() != files[member.name]:
                raise ValueError('Archive content mismatch')
    if target.stat().st_size > 100 * 1024 * 1024:
        raise ValueError('Payload exceeds app archive bound')
    payload = {'profile': parent['profile'], 'file': parent['file'], 'bytes': target.stat().st_size,
               'sha256': digest(target.read_bytes()), 'runtime_id': identity,
               'main_sha256': binaries['phi-modern']['sha256'],
               'features': ['auto-resources-v1', 'shared-multi-quant-v1', 'upstream-d57e0e6-v1']}
    return payload, provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base-assets', type=Path, required=True)
    parser.add_argument('--evidence-archive', type=Path, required=True)
    args = parser.parse_args()
    pin = read_json(ROOT / 'assets/upstream-runtime-build.json')
    if pin['candidate_commit'] != SOURCE or pin['native_acceptance'] is not False:
        raise ValueError('Unexpected build/source pin')
    for name, sha in pin['driver_files'].items():
        if name not in ('main.cpp', 'CMakeLists.txt', 'package-knc-profiles.sh') or digest((ROOT / 'tools/native-runner' / name).read_bytes()) != sha:
            raise ValueError('Driver source changed since cross-build')
    if digest(args.evidence_archive.read_bytes()) != pin['artifact_archive_sha256']:
        raise ValueError('Evidence archive changed')
    output = ROOT / 'assets/payloads'
    output.mkdir(parents=True, exist_ok=True)
    for name in ('runtime-3120A.tar', 'runtime-7120P.tar', 'baseline-runtime.tar'):
        if (output / name).exists():
            raise ValueError('Preserve existing payload: ' + name)
    config = read_json(ROOT / 'app/config/modern-runtime-1.5.3-paired.json')
    payloads, provenance = [], []
    with tarfile.open(args.evidence_archive, 'r:gz') as archive:
        for profile in ('3120A', '7120P'):
            parent = next(p for p in config['payloads'] if p['profile'] == 'xeon-phi-' + profile.lower())
            payload, evidence = compose(profile, archive, args.base_assets, output, pin, parent)
            payloads.append(payload)
            provenance.append(evidence)
    config.update(payloads=payloads, modern_source_commit=SOURCE, repair_version='upstream-d57e0e6-v1')
    manifest = read_json(ROOT / 'assets/runtime-manifest.json')
    backup = next(a for a in manifest['assets'] if a['kind'] == 'guard-backup')
    verified((args.base_assets / backup['file']).read_bytes(), backup)
    shutil.copyfile(args.base_assets / backup['file'], output / backup['file'])
    manifest.pop('native_payloads_unchanged_from', None)
    manifest['assets'] = [dict((k, v) for k, v in p.items() if k not in ('main_sha256', 'features')) for p in payloads]
    for asset in manifest['assets']:
        asset['kind'] = 'modern'
    manifest['assets'].append(backup)
    for name, value in [('app/config/modern-runtime.json', config), ('assets/runtime-manifest.json', manifest), ('docs/shared-runtime-provenance.json', provenance)]:
        (ROOT / name).write_bytes(json_bytes(value))
    print(json.dumps(payloads, indent=2))


if __name__ == '__main__':
    main()
