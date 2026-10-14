#!/usr/bin/env bash
# Full clean build in the pinned MPSS development VM. No card access or install.
set -euo pipefail
[[ $# == 3 ]] || { echo 'Usage: rebuild.sh PINNED_BASE_TAR NEW_WORK NEW_OUTPUT' >&2; exit 2; }
archive=$(realpath "$1")
work=$(realpath -m "$2")
output=$(realpath -m "$3")
adapter=$(cd "$(dirname "$0")"; pwd)
[[ ! -e $work && ! -e $output ]] || { echo 'Build destinations must be new' >&2; exit 2; }
[[ $(sha256sum "$archive" | cut -d' ' -f1) == ab529dee669f124b367c7f8770215ace4639045c4e094a995ccdb099d23151e5 ]]
cc=/usr/linux-k1om-4.7/bin/x86_64-k1om-linux-gcc
[[ $("$cc" -dumpversion) == 5.1.1 && $("$cc" -dumpmachine) == k1om-mpss-linux ]]
mkdir -p "$work/source"
tar -xf "$archive" -C "$work/source"
patch -d "$work/source" -p1 < "$adapter/runtime.patch"
cp "$adapter/knc.cpp" "$adapter/image-cache.h" "$work/source/examples/knc/"
bash "$work/source/examples/knc/build-candidates.sh" "$work/source" "$work/cross" "$output"
echo 'Cross-built only. Native correctness and throughput qualification still required.'
