#!/usr/bin/env bash
set -euo pipefail
source=/home/builder/knc-upstream-r1
build=/home/builder/knc-upstream-build-r1
output=/home/builder/knc-upstream-artifacts
cc=/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-gcc
cxx=/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-g++
readelf=/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-readelf
mkdir -p "$output"
for profile in 7120P 5110P 3120A; do
    case $profile in 3120A) l1=4; l2=16;; *) l1=8; l2=32;; esac
    dest=$output/$profile
    mkdir -p "$dest/bin" "$dest/lib"
    cmake -S "$source" -B "$build" -DGGML_KNC_PROFILE="$profile" \
        -DGGML_KNC_PREFETCH_L1="$l1" -DGGML_KNC_PREFETCH_L2="$l2" > "$dest/configure.log" 2>&1
    cmake --build "$build" -j4 > "$dest/build.log" 2>&1
    cp "$build/bin/llama-simple" "$build/bin/test-knc-mq" "$build/bin/test-knc-dot" \
       "$build/bin/test-quantize-fns" "$build/bin/test-backend-ops" "$build/bin/test-sampling" "$dest/bin/"
    "$cxx" -mknc -std=c++14 -O2 -fno-fast-math -fno-tree-vectorize -fno-tree-slp-vectorize \
        -DPHI_KNC_KERNELS -DPHI_LATEST_REFERENCE "-DPHI_PROFILE=\"$profile\"" \
        -I"$source/include" -I"$source/ggml/include" -I"$source/ggml/src/ggml-cpu/arch/knc" \
        /home/builder/main.cpp -Wl,--start-group "$build/src/libllama.a" "$build/ggml/src/libggml.a" \
        "$build/ggml/src/libggml-cpu.a" "$build/ggml/src/libggml-base.a" -Wl,--end-group \
        -fopenmp -pthread -ldl -lm -lrt -static-libstdc++ -static-libgcc \
        '-Wl,-rpath,$ORIGIN/../lib' -o "$dest/bin/phi-modern" > "$dest/driver-build.log" 2>&1
    cp -L "$("$cc" -print-file-name=libgomp.so.1)" "$dest/lib/libgomp.so.1"
    cp "$build/CMakeCache.txt" "$dest/CMakeCache.txt"
    cp "$build/ggml/src/knc/candidate-config.h" "$dest/candidate-config.h"
    for binary in "$dest"/bin/* "$dest"/lib/*; do
        "$readelf" -hW -dW -VW "$binary" > "$binary.abi.txt"
    done
    (cd "$dest"; sha256sum bin/* lib/* > SHA256SUMS)
    printf 'BUILT %s\n' "$profile"
done
