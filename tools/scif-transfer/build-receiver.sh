#!/bin/bash
# Development only: isolated Linux compiler environment, never run on the card.
set -eu
source /opt/mpss/3.8.6/environment-setup-k1om-mpss-linux
cd "$(dirname "$0")"
mkdir -p build
${CC} --sysroot="$OECORE_TARGET_SYSROOT" -mknc -O2 -std=gnu99 -Wall -Wextra -Werror \
  -fstack-protector -D_FORTIFY_SOURCE=2 receiver.c -lscif -o build/phichat-scif-recv
${READELF:-k1om-mpss-linux-readelf} -h -d -V build/phichat-scif-recv > build/elf.txt
${CC} --version > build/compiler.txt
# Inspect the ELF only. K1OM execution requires a separately authorized card test.
python3 - <<'PY'
import pathlib,struct
p=pathlib.Path('build/phichat-scif-recv').read_bytes()
assert p[:6]==b'\x7fELF\x02\x01' and struct.unpack_from('<H',p,18)[0]==181
t=pathlib.Path('build/elf.txt').read_text()
assert 'libscif.so.0' in t and 'libc.so.6' in t
print('PASS: K1OM SCIF receiver cross-built; not executed on hardware')
PY
