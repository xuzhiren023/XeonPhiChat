#!/usr/bin/env python3
"""Host-only shared engine, topology and optional release payload checks.

Requires Python 3.8 and Bash/awk for development; never executes a KNC binary.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import struct
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parent.parent
checks = 0
def check(ok, message):
    global checks
    if not ok: raise AssertionError(message)
    checks += 1

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bash', required=True)
    p.add_argument('--payloads', action='store_true')
    args = p.parse_args()
    def bash(script):
        return subprocess.run([args.bash, '-c', script], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    def q(path): return shlex.quote(Path(path).as_posix())
    for path in (ROOT/'app/scripts').glob('*.sh'):
        check(b'\r' not in path.read_bytes(), 'LF shell source: '+path.name)
        result = subprocess.run([args.bash, '-n', str(path)], capture_output=True)
        check(result.returncode == 0, 'Bash parse: '+path.name+' '+result.stderr.decode())
    with tempfile.TemporaryDirectory(prefix='phi-shared-fixture-') as temp:
        temp = Path(temp)
        topology = temp/'topology.txt'
        awk = ROOT/'app/scripts/shared-knc-affinity.awk'
        for cores in (57,61):
            for interleaved in (False,True):
                groups = [[c+i*cores for i in range(4)] if interleaved else list(range(c*4,c*4+4)) for c in range(cores)]
                text = 'allowed\t0-'+str(cores*4-1)+'\n'
                text += ''.join('cpu\t{}\t{}\n'.format(cpu, ','.join(map(str,g))) for g in groups for cpu in g)
                topology.write_bytes(text.encode())
                for smt in (1,2,3,4):
                    workers=(cores-1)*smt
                    result=bash('awk -v cores={} -v workers={} -f {} {}'.format(cores, workers, q(awk), q(topology)))
                    check(result.returncode == 0, 'topology accepted: '+result.stderr)
                    cpus=list(map(int,result.stdout.split()))
                    expected=[g[i] for i in range(smt) for g in groups[1:]]
                    check(cpus==expected and len(set(cpus))==workers and not set(cpus)&set(groups[0]), 'spread threads; reserve CPU0 entire core')
                result=bash('awk -v cores={} -v workers=5 -f {} {}'.format(cores,q(awk),q(topology)))
                check(result.returncode!=0, 'invalid worker count rejected')
                topology.write_bytes(text.replace('allowed\t0-', 'allowed\t1-').encode())
                result=bash('awk -v cores={} -v workers={} -f {} {}'.format(cores,cores-1,q(awk),q(topology)))
                check(result.returncode!=0, 'restricted affinity rejected instead of oversubscribing')
        smaps=temp/'smaps.txt'
        records=('1000-9000 r--s 0 00:01 1 model.gguf\nSize: 32 kB\nRss: 24 kB\n'
                 'a000-c000 rw-p 0 00:00 0 [heap]\nSize: 8 kB\nRss: 8 kB\n')
        # The KNC proc stream repeated complete VMA records during a native
        # large-context allocation. Each address range must contribute once.
        smaps.write_bytes((records*5).encode())
        result=bash('awk -v path=model.gguf -f {} {}'.format(q(ROOT/'app/scripts/model-map.awk'),q(smaps)))
        check(result.returncode==0 and result.stdout.strip()=='32 24 32 0', 'repeated VMA rows do not inflate model or additional RSS: '+result.stdout+result.stderr)
        smaps.write_bytes((records+records.replace('r--s','rw-p')).encode())
        result=bash('awk -v path=model.gguf -f {} {}'.format(q(ROOT/'app/scripts/model-map.awk'),q(smaps)))
        check(result.returncode==0 and int(result.stdout.split()[-1])>0, 'duplicate header does not hide an unsafe model mapping')
        identity='phichat142-modern-'+'a'*16
        runtime=temp/'runtime with spaces'
        runtime.mkdir()
        for name,value in [('modern-source.txt','6783b11fb0889d68d0046176b4cc92ceee1961b0'),('modern-runtime-passed.txt',identity),('shared-runtime-id.txt',identity)]:
            (runtime/name).write_bytes((value+'\n').encode())
        script='''set -eu
fail() { echo "$*" >&2; exit 1; }
runtime=RUNTIME
RUNTIME_FAMILY=modern-knc
MODERN_ENGINE_VARIANT=shared
MODERN_RUNTIME_ID=IDENTITY
source ADAPTER
phi_select_engine
[[ $engine == "$runtime/shared/bin/phi-modern" ]]
'''.replace('runtime=RUNTIME','runtime='+q(runtime)).replace('=IDENTITY','='+identity).replace('source ADAPTER','source '+q(ROOT/'app/scripts/engine-llama-cli-v1.sh'))
        check(bash(script).returncode==0, 'shared selection uses shared binary')
        (runtime/'modern-source.txt').write_bytes(b'd57e0e6e4882445bc625aaee47f91db469f9fc22\n')
        updated='export MODERN_SOURCE_COMMIT=d57e0e6e4882445bc625aaee47f91db469f9fc22\n'+script
        check(bash(updated).returncode==0, 'rebased source pin routes to shared engine')
        check(bash(script).returncode!=0, 'source mismatch is rejected')
        (runtime/'modern-source.txt').write_bytes(b'6783b11fb0889d68d0046176b4cc92ceee1961b0\n')
        (runtime/'shared-runtime-id.txt').write_bytes(b'wrong\n')
        check(bash(script).returncode!=0, 'wrong shared receipt fails closed')
        (runtime/'shared-runtime-id.txt').unlink()
        check(bash(script).returncode!=0, 'missing shared engine never falls back to old binary')
    if args.payloads:
        manifest=json.loads((ROOT/'assets/runtime-manifest.json').read_text())
        configs=[json.loads((ROOT/'app/config'/name).read_text()) for name in
                 ('modern-runtime.json','modern-runtime-numerics-r3.json')]
        for asset in manifest['assets']:
            path=ROOT/'assets/payloads'/asset['file']
            check(path.stat().st_size==asset['bytes'] and hashlib.sha256(path.read_bytes()).hexdigest()==asset['sha256'], 'release payload hash/size '+asset['file'])
            if asset['kind']!='modern': continue
            config,pin=next((c,x) for c in configs for x in c['payloads']
                            if x['profile']==asset['profile'] and x['runtime_id']==asset['runtime_id'])
            check(all(pin[k]==asset[k] for k in ('runtime_id','sha256','bytes','file')), 'installer and app select same payload')
            with tarfile.open(path) as tf:
                names=tf.getnames()
                check('modern-runtime-passed.txt' not in names and 'build-passed.txt' not in names, 'no inherited native acceptance')
                check(not any(n.startswith('optimized/') for n in names), 'obsolete Q5-only engine not shipped')
                evidence=json.load(tf.extractfile('shared/provenance.json'))
                check(evidence.get('source_commit',evidence.get('source'))==config['modern_source_commit']==tf.extractfile('modern-source.txt').read().decode().strip(), 'compiled candidate source pin is propagated')
                if 'knc-text-image-r1' in pin.get('features',[]):
                    build=json.loads((ROOT/'assets/multimodal-runtime-build.json').read_text())
                    check(evidence['patch_sha256']==build['patch_sha256'], 'required compiler metadata fix is retained')
                    binaries={n[len('shared/bin/'):]: {'sha256':s}
                              for n,s in evidence['files'].items() if n.startswith('shared/bin/')}
                    expected={'phi-modern','test-knc-dot','test-knc-mq','test-knc-mtmd'}
                else:
                    check(evidence['native_acceptance'] is False, 'package carries no native acceptance claim')
                    binaries=evidence['binaries']
                    expected={'phi-modern','test-knc-dot','test-knc-mq','test-backend-ops','test-quantize-fns','test-sampling'}
                check(set(binaries)==expected, 'current runner and native tests are all present')
                for name,item in binaries.items():
                    data=tf.extractfile('shared/bin/'+name).read()
                    check(hashlib.sha256(data).hexdigest()==item['sha256'] and len(data)==item.get('bytes',len(data)), 'exact audited native binary')
                    check(data[:6]==b'\x7fELF\x02\x01' and struct.unpack_from('<H',data,18)[0]==181, 'native K1OM ELF')
                    check(b'$ORIGIN/../lib' in data, 'private OpenMP library resolution')
                for src,dst in [('shared-knc-env.sh','configure.sh'),('shared-knc-affinity.awk','knc-affinity.awk')]:
                    check(tf.extractfile('shared/'+dst).read()==(ROOT/'app/scripts'/src).read_bytes(), 'packaged wrapper matches source')
                check(tf.extractfile('shared-runtime-id.txt').read().decode().strip()==pin['runtime_id'], 'exact shared runtime identity')
    print('PASS: {} shared runtime host/package checks; no card or services touched.'.format(checks))

if __name__=='__main__': main()
