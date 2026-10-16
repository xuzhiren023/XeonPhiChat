#!/usr/bin/env python3
"""Inspect a completed portable cross-build; never execute target binaries."""
import argparse
import json
from pathlib import Path
import shlex
import struct
import subprocess
import importlib.util

here = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('portable_recipe', here / 'rebuild.py')
recipe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recipe)
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('work', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--toolchain-root', type=Path, default=Path('/usr/linux-k1om-4.7'))
a = p.parse_args()
source, build = a.work.resolve() / 'source', a.work.resolve() / 'cross'
checks = []


def check(ok, name):
    if not ok:
        raise RuntimeError(name)
    checks.append(name)


for name, relative in recipe.OVERLAYS.items():
    check((here / name).read_bytes() == (source / relative).read_bytes(), 'exact overlay: ' + name)
commands = json.loads((build / 'compile_commands.json').read_text())
def command(suffix):
    found = [c for c in commands if c['file'].endswith(suffix)]
    check(len(found) == 1, 'single compilation: ' + suffix)
    return shlex.split(found[0]['command'])

mq = command('/arch/knc/knc-mq.c')
for flag in ['-mknc', '-O3', '-funroll-loops', '-fexcess-precision=standard',
             '-mstringop-strategy=unrolled_loop', '-fno-fast-math',
             '-fno-tree-vectorize', '-fno-tree-slp-vectorize']:
    check(flag in mq, 'quant flag: ' + flag)
check('-ffast-math' not in mq, 'quant path retains strict math')
for name in ['dense.S', 'panel8.S']:
    args = command('/arch/knc/' + name)
    check('-D__KNC__' in args and '-mknc' in args, 'IMCI assembly flags: ' + name)
    obj = build / 'ggml/src/CMakeFiles/ggml-cpu.dir/ggml-cpu/arch/knc' / (name + '.o')
    text = subprocess.check_output([str(a.toolchain_root / 'bin/x86_64-k1om-linux-objdump'), '-d', str(obj)],
                                   universal_newlines=True)
    check('(bad)' not in text, 'IMCI disassembly: ' + name)
    (a.output / (name + '.disassembly.txt')).write_text(text)
prefix = command('/examples/knc/test-prefix.cpp')
check('-UNDEBUG' in prefix and prefix.index('-UNDEBUG') > prefix.index('-DNDEBUG'), 'prefix assertions active')
for c in commands:
    check('/knc-decode-next/' not in c['command'] and '/knc-performance-next/' not in c['command']
          and '/phichat-prime-162/' not in c['command'], 'no historical build dependency: ' + Path(c['file']).name)
links = list(build.rglob('link.txt'))
check(bool(links), 'generated link commands retained')
for path in links:
    text = path.read_text()
    check(all(part not in text for part in ['/knc-decode-next/', '/knc-performance-next/', '/phichat-prime-162/']),
          'no historical link dependency: ' + str(path.relative_to(build)))
for binary in sorted((a.output / 'bin').iterdir()):
    with binary.open('rb') as f:
        header = f.read(20)
    check(header[:6] == b'\x7fELF\x02\x01' and struct.unpack_from('<H', header, 18)[0] == 181,
          'ELF64 K1OM: ' + binary.name)
receipt = json.loads((a.output / 'build-receipt.json').read_text())
check(receipt['cross_built'] and not receipt['native_tested'] and not receipt['installed'], 'qualification remains scoped')
result = dict(passed=True, count=len(checks), checks=checks, native_executed=False,
              note='Source, compiler wiring and ELF inspection only; not native behavioral acceptance')
(a.output / 'portable-verification.json').write_text(json.dumps(result, indent=2) + '\n')
print('PASS %d portable source/compiler/ELF checks; no card execution' % len(checks))
