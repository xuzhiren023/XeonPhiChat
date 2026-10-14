#!/usr/bin/env bash
# Developer-only cross build. Does not connect to, install on, or execute on a Phi.
set -euo pipefail
[[ $# == 3 ]] || { echo "Usage: $0 FRESH_61e9799_SOURCE NEW_BUILD NEW_OUTPUT" >&2; exit 1; }
source=$(realpath "$1")
build=$(realpath -m "$2")
output=$(realpath -m "$3")
adapter=$(cd "$(dirname "$0")"; pwd)
[[ ! -e $build && ! -e $output ]]
# Supply a fresh checkout/archive of 61e97998bf49c2d425563920b7e83e52b5ae57a6.
patch -d "$source" -p1 < "$adapter/../multimodal/metadata-fix.patch"
[[ $(sha256sum "$source/tools/mtmd/clip.cpp" | cut -d' ' -f1) == b19dcda48d0ed84653928c87ddd4c349fa9e61b765b8e3ff372944497ee98b13 ]]
cp "$adapter/knc.cpp" "$adapter/CMakeLists.txt" "$source/examples/knc/"
mkdir -p "$output/bin" "$output/lib"
cmake -S "$source" -B "$build" -DCMAKE_TOOLCHAIN_FILE="$source/cmake/k1om.cmake" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE='-O2 -DNDEBUG' -DCMAKE_CXX_FLAGS_RELEASE='-O2 -DNDEBUG' \
  -DGGML_KNC=ON -DGGML_KNC_PROFILE=7120P -DGGML_KNC_PREFETCH_L1=8 -DGGML_KNC_PREFETCH_L2=32 \
  -DGGML_KNC_PREFETCH_STEP=64 -DGGML_KNC_PREFETCH_Q8=ON \
  -DGGML_NATIVE=OFF -DGGML_CPU_REPACK=OFF -DGGML_LLAMAFILE=OFF -DGGML_BACKEND_DL=OFF -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_COMMON=OFF -DLLAMA_BUILD_TOOLS=OFF -DLLAMA_BUILD_APP=OFF -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_BUILD_EXAMPLES=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_MTMD=ON -DLLAMA_BUILD_KNC_RUNNER=ON \
  -DLLAMA_KNC_TESTS=OFF -DLLAMA_KNC_HOST_REFERENCE=OFF -DMTMD_VIDEO=OFF -DLLAMA_SUBPROCESS=OFF \
  > "$output/configure.log" 2>&1
cmake --build "$build" --target llama-knc-runner -j "${BUILD_JOBS:-4}" > "$output/build.log" 2>&1
cp "$build/bin/llama-knc-runner" "$output/bin/phi-prime"
cc=/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-gcc
cp -L "$("$cc" -print-file-name=libgomp.so.1)" "$output/lib/"
(cd "$output"; sha256sum bin/phi-prime lib/libgomp.so.1 > SHA256SUMS; tar -cf prime-7120P.tar bin/phi-prime lib/libgomp.so.1)
echo 'Cross build complete; hardware validation pending.'
