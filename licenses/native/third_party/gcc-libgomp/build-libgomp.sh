#!/usr/bin/env bash
set -euo pipefail
# Run after extracting libgomp-source.tar.gz. Installs only into the SDK sysroot.
knc_source=$(cd "${1:-gcc-5.1.1-knc}" && pwd)
knc_build=${2:-libgomp-build}
knc_sdk=${KNC_SDK_ROOT:-/opt/mpss/3.8.6}
knc_tools=$knc_sdk/sysroots/x86_64-mpsssdk-linux/usr/bin/k1om-mpss-linux
knc_sysroot=$knc_sdk/sysroots/k1om-mpss-linux
knc_cc=${KNC_CC:-/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-gcc}
knc_cxx=${KNC_CXX:-/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-g++}
mkdir -p "$knc_build"
cd "$knc_build"
"$knc_source/libgomp/configure"   --build=x86_64-linux-gnu --host=k1om-mpss-linux --target=k1om-mpss-linux   --prefix="$knc_sysroot/usr" --libdir="$knc_sysroot/usr/lib64"   --disable-multilib --enable-shared --enable-static   CC="$knc_cc" CXX="$knc_cxx"   AR="$knc_tools/k1om-mpss-linux-ar" RANLIB="$knc_tools/k1om-mpss-linux-ranlib"   CFLAGS='-O2 -mknc'
make -j4 libgomp.la LIBS='-lrt -ldl'
make install-toolexeclibLTLIBRARIES install-nodist_libsubincludeHEADERS install-nodist_toolexeclibHEADERS LIBS='-lrt -ldl'
# The standalone build omits GCC's private version field in libsubincludedir.
install -m 644 omp.h "$knc_sysroot/usr/include/omp.h"
"$knc_tools/k1om-mpss-linux-readelf" -h "$knc_sysroot/usr/lib64/libgomp.so.1.0.0"
