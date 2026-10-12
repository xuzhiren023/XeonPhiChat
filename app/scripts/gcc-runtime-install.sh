#!/usr/bin/env bash
# Runs only under the accepted native guard, in a new isolated runtime folder.
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
runtime=${1:?}; baseline=${2:?}; token=${3:?}; archive=${4:?}; identity=${5:?}; source=${6:?}
[[ $runtime =~ ^/root/knc-phase3-run-gcc021-[a-f0-9]{32}$ ]] || fail path
[[ $baseline =~ ^/root/knc-phase3-run-[A-Za-z0-9-]+$ ]] || fail baseline
[[ $token =~ ^[a-f0-9]{32}$ ]] || fail token
[[ $archive == runtime-3120A.tar || $archive == runtime-7120P.tar ]] || fail archive
[[ $identity =~ ^phichat138-gcc021-[a-f0-9]{16}$ ]] || fail identity
[[ $source == 03a8b80c7d502797325788f604248dd4aabdf5ef ]] || fail source
[[ $(uname -m) == k1om ]] || fail 'K1OM execution required'
lock=/tmp/knc-phase3-workload.lock
[[ -f $lock/phi-chat-owner && $(cat "$lock/phi-chat-owner") == "$token" ]] || fail 'workload ownership'
[[ ! -f $lock/worker-pid ]] || fail 'worker already exists'
printf '%s\n' "$$" > "$lock/worker-pid"
cleanup() { rm -f "$lock/worker-pid"; }
trap cleanup EXIT
unset LD_PRELOAD LD_LIBRARY_PATH OMP_THREAD_LIMIT OMP_NUM_THREADS
export OMP_NUM_THREADS=4 OMP_DYNAMIC=FALSE
source "$runtime/elf-check.sh"
check_memory() {
    local free available credit
    read -r free available credit < <(awk -f "$runtime/memory-info.awk" /proc/meminfo)
    [[ $available =~ ^[0-9]+$ && $available -ge 524288 ]] || fail 'runtime install needs 512 MiB allocatable GDDR'
}
check_memory
[[ $(cat "$baseline/build-passed.txt") == "$source" ]] || fail 'baseline source pin'
check_elf "$baseline/guard"
tar -xf "$runtime/$archive" -C "$runtime"
[[ $(cat "$runtime/runtime-id.txt") == "$identity" ]] || fail 'payload identity'
cp "$baseline/guard" "$runtime/guard"
chmod +x "$runtime/guard" "$runtime/llama/"* "$runtime/tests/"*
for binary in "$runtime/llama/main" "$runtime/llama/llama-bench" "$runtime/llama/test-phase3-numerics" "$runtime/llama/test-quantize-fns" "$runtime/tests/test-knc" "$runtime/lib/libgomp.so.1"; do check_elf "$binary"; done
printf 'Runtime: %s\nMachine: %s\n' "$identity" "$(uname -a)"
# Only the supplied standalone test lacks an ORIGIN runpath. Its library path
# is scoped to that command; inference uses the new main's private runpath.
check_memory
LD_LIBRARY_PATH="$runtime/lib" "$runtime/tests/test-knc"
check_memory
"$runtime/llama/test-phase3-numerics" --trace
check_memory
"$runtime/llama/test-quantize-fns"
"$runtime/llama/main" --help > "$runtime/main-help.txt" 2>&1
[[ -s $runtime/main-help.txt ]] || fail 'CLI startup produced no help'
printf '%s\n' "$source" > "$runtime/build-passed.txt"
printf '%s\n' "$identity" > "$runtime/gcc-runtime-passed.txt"
rm -f "$runtime/$archive"
printf 'PASS: native kernel suites, GGML numerical tests and CLI startup. Model throughput is unmeasured.\n'
