#!/usr/bin/env python3
"""Clean, offline context-matrix-r2 build. Never connects to or installs on a card."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

HERE = Path(__file__).resolve().parent
BASE_ID = 'ab529dee669f124b367c7f8770215ace4639045c4e094a995ccdb099d23151e5'
BASE_COMMIT = '61e97998bf49c2d425563920b7e83e52b5ae57a6'
OVERLAYS = {
    'knc.cpp': 'examples/knc/knc.cpp',
    'prefix-cache.h': 'examples/knc/prefix-cache.h',
    'image-cache.h': 'examples/knc/image-cache.h',
    'ggml-cpu.c': 'ggml/src/ggml-cpu/ggml-cpu.c',
    'dense.inc': 'ggml/src/ggml-cpu/dense.inc',
    'matmul-panel8.inc': 'ggml/src/ggml-cpu/matmul-panel8.inc',
    'knc-mq-panel8.c': 'ggml/src/ggml-cpu/arch/knc/knc-mq.c',
    'dense.S': 'ggml/src/ggml-cpu/arch/knc/dense.S',
    'panel8.S': 'ggml/src/ggml-cpu/arch/knc/panel8.S',
    'test-prefix.cpp': 'examples/knc/test-prefix.cpp',
    'test-dense.cpp': 'examples/knc/test-dense.cpp',
    'test-native-conversation.cpp': 'examples/knc/test-native-conversation.cpp',
    'test-trained-image.cpp': 'examples/knc/test-trained-image.cpp',
    'bench-dense.cpp': 'examples/knc/bench-dense.cpp',
    'affinity-check.h': 'examples/knc/affinity-check.h',
}
TESTS = ['test-knc-context-dense', 'test-conversation-native',
         'test-knc-trained-image', 'bench-knc-context-dense', 'test-knc-prefix']


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('base_archive', type=Path, help='Previously verified retained base source archive')
    p.add_argument('work', type=Path, help='New private source/build directory')
    p.add_argument('output', type=Path, help='New private output directory')
    p.add_argument('--profile', choices=['3120A', '5110P', '7120P'], default='7120P')
    p.add_argument('--jobs', type=int, default=2)
    p.add_argument('--toolchain-root', type=Path, default=Path('/usr/linux-k1om-4.7'))
    p.add_argument('--sysroot', type=Path, default=Path('/opt/mpss/3.8.6/sysroots/k1om-mpss-linux'))
    p.add_argument('--prepare-only', action='store_true', help='Extract, patch and wire CMake only')
    a = p.parse_args()
    if a.jobs < 1:
        p.error('--jobs must be positive')
    archive, work, output = (x.resolve() for x in (a.base_archive, a.work, a.output))
    if work.exists() or output.exists():
        p.error('Work and output destinations must both be new; no existing tree is modified')
    if work == output or work in output.parents or output in work.parents:
        p.error('Work and output must be separate, non-nested directories')
    if not archive.is_file():
        p.error('Missing retained base source archive')
    for name in list(OVERLAYS) + ['decode3-runtime.patch', 'backend.cmake', 'tests.cmake']:
        if not (HERE / name).is_file():
            p.error('Incomplete portable source package: ' + name)
    records = []
    source, build = work / 'source', work / 'cross'
    work.mkdir(parents=True)
    output.mkdir(parents=True)

    def run(cmd, name, cwd=None):
        cmd = [str(x) for x in cmd]
        records.append(dict(name=name, argv=cmd, cwd=str(cwd) if cwd else None))
        (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
        print(name, flush=True)
        with (output / (name + '.log')).open('w') as log:
            subprocess.run(cmd, cwd=cwd, check=True, stdout=log, stderr=subprocess.STDOUT)

    source.mkdir()
    with tarfile.open(archive, 'r:*') as t:
        # This pinned git-export archive has only files and directories. Refuse
        # links, devices and paths escaping the new destination before extraction.
        members = t.getmembers()
        for member in members:
            dest = (source / member.name).resolve()
            if not (member.isfile() or member.isdir()) or (dest != source and source not in dest.parents):
                raise ValueError('Unexpected source archive member: ' + member.name)
        t.extractall(source, members=members)
    patch = HERE / 'decode3-runtime.patch'
    run(['patch', '--batch', '--forward', '--fuzz=0', '--dry-run', '-p1', '-i', patch], 'patch-check', source)
    run(['patch', '--batch', '--forward', '--fuzz=0', '-p1', '-i', patch], 'patch-apply', source)
    for name, relative in OVERLAYS.items():
        dest = source / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(HERE / name, dest)
    backend = source / 'ggml/src/ggml-cpu/arch/knc'
    shutil.copyfile(HERE / 'backend.cmake', backend / 'context-matrix.cmake')
    with (backend / 'knc.cmake').open('a') as f:
        f.write('\ninclude(${knc}/context-matrix.cmake)\n')
    shutil.copyfile(HERE / 'tests.cmake', source / 'examples/knc/context-matrix-tests.cmake')
    with (source / 'examples/knc/CMakeLists.txt').open('a') as f:
        f.write('\ninclude(${CMAKE_CURRENT_LIST_DIR}/context-matrix-tests.cmake)\n')
    receipt = dict(schema=1, candidate='context-matrix-r2-portable', profile=a.profile,
                   retained_base_id=BASE_ID, base_commit=BASE_COMMIT,
                   base_identity='caller-retained provenance; no repeated hash scan',
                   base_bytes=archive.stat().st_size, overlays=OVERLAYS,
                   prepared=True, cross_built=False, native_tested=False,
                   installed=False, requires_native_acceptance=True,
                   note='Fresh rebuild is not automatically covered by the delivered binary receipt')
    (output / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    if a.prepare_only:
        print('Prepared source only. No compiler, runtime, or card workload was invoked.')
        return
    cc = a.toolchain_root / 'bin/x86_64-k1om-linux-gcc'
    def query(flag):
        return subprocess.check_output([str(cc), flag], universal_newlines=True).strip()
    if query('-dumpversion') != '5.1.1' or query('-dumpmachine') != 'k1om-mpss-linux':
        raise RuntimeError('Requires the pinned MPSS GCC 5.1.1 K1OM compiler')
    if Path(query('-print-sysroot')).resolve() != a.sysroot.resolve():
        raise RuntimeError('Compiler sysroot differs from requested MPSS sysroot')
    l1, l2 = (4, 16) if a.profile == '3120A' else (8, 32)
    flags = dict(CMAKE_BUILD_TYPE='Release', CMAKE_TOOLCHAIN_FILE=source / 'cmake/k1om.cmake',
                 KNC_TOOLCHAIN_ROOT=a.toolchain_root.resolve(), KNC_SYSROOT=a.sysroot.resolve(),
                 CMAKE_EXPORT_COMPILE_COMMANDS='ON', GGML_KNC='ON', GGML_KNC_PROFILE=a.profile,
                 GGML_KNC_PREFETCH_L1=l1, GGML_KNC_PREFETCH_L2=l2, GGML_KNC_PREFETCH_STEP=64,
                 GGML_KNC_PREFETCH_Q8='ON', GGML_NATIVE='OFF', GGML_CPU_REPACK='OFF',
                 GGML_LLAMAFILE='OFF', GGML_BACKEND_DL='OFF', BUILD_SHARED_LIBS='OFF',
                 LLAMA_BUILD_COMMON='OFF', LLAMA_BUILD_TOOLS='OFF', LLAMA_BUILD_APP='OFF',
                 LLAMA_BUILD_TESTS='ON', LLAMA_BUILD_EXAMPLES='ON', LLAMA_KNC_TESTS='ON',
                 LLAMA_BUILD_MTMD='ON', LLAMA_BUILD_KNC_RUNNER='ON', LLAMA_KNC_HOST_REFERENCE='OFF',
                 MTMD_VIDEO='OFF', LLAMA_SUBPROCESS='OFF')
    run(['cmake', '-S', source, '-B', build] + ['-D%s=%s' % item for item in flags.items()], 'configure')
    targets = ['llama-knc-runner', 'test-knc-mq', 'test-knc-dot', 'test-knc-mtmd'] + TESTS
    run(['cmake', '--build', build, '--target'] + targets + ['-j', a.jobs], 'build')
    (output / 'bin').mkdir()
    (output / 'lib').mkdir()
    for target in targets:
        name = 'phi-prime-context-matrix-r2-rebuilt' if target == 'llama-knc-runner' else target
        shutil.copy2(build / 'bin' / target, output / 'bin' / name)
    shutil.copy2(query('-print-file-name=libgomp.so.1'), output / 'lib/libgomp.so.1')
    for name in ['compile_commands.json', 'CMakeCache.txt']:
        shutil.copy2(build / name, output / name)
    shutil.copy2(build / 'ggml/src/knc/candidate-config.h', output / 'candidate-config.h')
    readelf = a.toolchain_root / 'bin/x86_64-k1om-linux-readelf'
    for binary in sorted((output / 'bin').iterdir()):
        run([readelf, '-hW', '-dW', '-VW', binary], binary.name + '-abi')
    receipt['cross_built'] = True
    (output / 'build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('Clean cross-build complete. No card workloads, installation, or repeated hash scans.')


if __name__ == '__main__':
    main()
