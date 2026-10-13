#!/usr/bin/env bash
# Runs only under the accepted native guard, in a new isolated runtime folder.
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
runtime=${1:?}; baseline=${2:?}; token=${3:?}; archive=${4:?}; identity=${5:?}; source=${6:?}
modern_source=${7:-6783b11fb0889d68d0046176b4cc92ceee1961b0}
case $modern_source in 6783b11fb0889d68d0046176b4cc92ceee1961b0|d57e0e6e4882445bc625aaee47f91db469f9fc22|61e97998bf49c2d425563920b7e83e52b5ae57a6) ;; *) fail 'Unsupported modern source revision';; esac
[[ $runtime =~ ^/root/knc-phase3-run-modern14[012]-[a-f0-9]{32}$ ]] || fail path
[[ $baseline =~ ^/root/knc-phase3-run-[A-Za-z0-9-]+$ ]] || fail baseline
[[ $token =~ ^[a-f0-9]{32}$ ]] || fail token
[[ $archive == runtime-3120A.tar || $archive == runtime-7120P.tar ]] || fail archive
[[ $identity =~ ^phichat14[012]-modern-[a-f0-9]{16}$ ]] || fail identity
[[ $source == 03a8b80c7d502797325788f604248dd4aabdf5ef ]] || fail source
[[ $(uname -m) == k1om ]] || fail 'K1OM execution required'
lock=/tmp/knc-phase3-workload.lock
[[ -f $lock/phi-chat-owner && $(cat "$lock/phi-chat-owner") == "$token" ]] || fail 'workload ownership'
[[ ! -f $lock/worker-pid ]] || fail 'worker already exists'
printf '%s\n' "$$" > "$lock/worker-pid"
cleanup() { rm -f "$lock/worker-pid"; }
trap cleanup EXIT
stage=initialization
on_error() {
    local rc=$? line=$1
    trap - ERR
    set +e
    printf 'FAIL: stage=%s exit=%s line=%s\n' "$stage" "$rc" "$line" >&2
    exit "$rc"
}
trap 'on_error "$LINENO"' ERR
step() { stage=$1; printf 'INSTALL_STAGE: %s\n' "$stage" >&2; }
unset LD_PRELOAD LD_LIBRARY_PATH OMP_THREAD_LIMIT OMP_NUM_THREADS
unset PHI_KNC_Q5_MODE PHI_KNC_F32_MODE PHI_KNC_EXTENDED PHI_KNC_TRACE
unset GGML_KNC_MQ GGML_KNC_MQ_ROWS
unset BP_KNC_CPUS BP_Q5_SPECIALIZE GOMP_CPU_AFFINITY OMP_PROC_BIND OMP_PLACES KMP_AFFINITY
export OMP_NUM_THREADS=4 OMP_DYNAMIC=FALSE
source "$runtime/elf-check.sh"
check_memory() {
    local free available credit
    read -r free available credit < <(awk -f "$runtime/memory-info.awk" /proc/meminfo)
    [[ $available =~ ^[0-9]+$ && $available -ge 524288 ]] || fail 'runtime install needs 512 MiB allocatable GDDR'
}
check_memory
[[ $(cat "$runtime/guard-source.txt") == "$source" ]] || fail 'baseline source pin'
check_elf "$runtime/guard"
step extract-prebuilt-runtime
tar -xf "$runtime/$archive" -C "$runtime"
[[ $(cat "$runtime/runtime-id.txt") == "$identity" ]] || fail 'payload identity'
chmod +x "$runtime/guard" "$runtime/llama/"* "$runtime/tests/"*
for binary in "$runtime/llama/main" "$runtime/llama/llama-bench" "$runtime/llama/test-phase3-numerics" "$runtime/llama/test-quantize-fns" "$runtime/tests/test-knc" "$runtime/lib/libgomp.so.1" "$runtime/llama/phi-modern" "$runtime/tests/test-modern-ops"; do check_elf "$binary"; done
modern_engine="$runtime/llama/phi-modern"
modern_test="$runtime/tests/test-modern-ops"
if [[ -f $runtime/shared-runtime-id.txt ]]; then
    [[ $(cat "$runtime/shared-runtime-id.txt") == "$identity" && ! -f $runtime/optimized-runtime-id.txt ]] || fail 'Shared payload identity'
    case "$archive:$(cat "$runtime/parent-runtime-id.txt")" in
        runtime-3120A.tar:phichat142-modern-346789f47a328478|runtime-7120P.tar:phichat142-modern-9610d4c7df2513c6) ;;
        *) fail 'Shared runtime base/profile';;
    esac
    chmod +x "$runtime/shared/bin/"*
    for binary in "$runtime/shared/bin/"* "$runtime/shared/lib/libgomp.so.1"; do check_elf "$binary"; done
    modern_engine="$runtime/shared/bin/phi-modern"
    modern_test="$runtime/shared/bin/test-modern-ops"
    if [[ $modern_source == d57e0e6e4882445bc625aaee47f91db469f9fc22 || $modern_source == 61e97998bf49c2d425563920b7e83e52b5ae57a6 ]]; then
        modern_test="$runtime/shared/bin/test-knc-dot"
    fi
    step shared-multi-quant-graph
    # Exercise each row tile with mixed K-quants, strides and fallbacks.
    for rows in 1 2 4 8; do
        GGML_KNC_MQ=1 GGML_KNC_MQ_ROWS=$rows "$runtime/shared/bin/test-knc-mq"
    done
    export GGML_KNC_MQ=1 GGML_KNC_MQ_ROWS=4
elif [[ -f $runtime/optimized-runtime-id.txt ]]; then
    [[ $archive == runtime-7120P.tar && $(cat "$runtime/optimized-runtime-id.txt") == "$identity" ]] || fail 'Optimized payload identity/profile'
    chmod +x "$runtime/optimized/bin/"*
    for binary in "$runtime/optimized/bin/"* "$runtime/optimized/lib/libgomp.so.1"; do check_elf "$binary"; done
    modern_engine="$runtime/optimized/bin/phi-modern"
    modern_test="$runtime/optimized/bin/test-modern-ops"
    step optimized-graph-numerics
    BP_Q5_SPECIALIZE=1 "$runtime/optimized/bin/test-q5-candidate"
    BP_Q5_SPECIALIZE=0 "$runtime/optimized/bin/test-q5-candidate"
    step optimized-pinning
    "$runtime/optimized/bin/test-q5-pinning" self
fi
printf 'Runtime: %s\nMachine: %s\n' "$identity" "$(uname -a)"
# Only the supplied standalone test lacks an ORIGIN runpath. Its library path
# is scoped to that command; inference uses the new main's private runpath.
check_memory
step vendor-correctness
LD_LIBRARY_PATH="$runtime/lib" "$runtime/tests/test-knc"
check_memory
# Select exactly the same historical dispatch as chat-worker.sh. The default
# inside the supplied ELF is legacy; merely copying it would not enable repair.
if [[ -f $runtime/q5-repair.json ]]; then
    repair_identity=$identity
    if [[ -f $runtime/shared-runtime-id.txt ]]; then repair_identity=$(cat "$runtime/parent-runtime-id.txt"); fi
    case $repair_identity in
        phichat142-modern-3554c44c1f51ed57|phichat142-modern-40dbb7531d2e5096|phichat142-modern-346789f47a328478|phichat142-modern-3673c2e612bc757d|phichat142-modern-9610d4c7df2513c6) ;;
        *) fail 'Unrecognized Q5 repair runtime';;
    esac
    step q5-repair-correctness
    check_elf "$runtime/tests/test-q5-repair"
    "$runtime/tests/test-q5-repair"
    export PHI_KNC_Q5_MODE=repair PHI_KNC_F32_MODE=vendor PHI_KNC_EXTENDED=0
    printf 'Q5 mode: repair; F32: vendor; other K-quants: historical; tracing: off\n'
fi
step legacy-numerics
"$runtime/llama/test-phase3-numerics" --trace
check_memory
step quantization-correctness
"$runtime/llama/test-quantize-fns"
step legacy-cli-startup
"$runtime/llama/main" --help > "$runtime/main-help.txt" 2>&1
[[ -s $runtime/main-help.txt ]] || fail 'CLI startup produced no help'
unset PHI_KNC_Q5_MODE PHI_KNC_F32_MODE PHI_KNC_EXTENDED PHI_KNC_TRACE
step modern-operators
"$modern_test"
if [[ $modern_source == d57e0e6e4882445bc625aaee47f91db469f9fc22 ]]; then
    step rebased-backend-operators
    "$runtime/shared/bin/test-backend-ops" -b CPU -o MUL_MAT -p 'type_a=q[3456]_K,type_b=f32,m=(1|7|8|17|33|65),n=(1|3),k=512,'
    step rebased-quantization-and-sampling
    "$runtime/shared/bin/test-quantize-fns"
    "$runtime/shared/bin/test-sampling"
fi
# Throughput benchmarking belongs in developer qualification, not installation.
if [[ $modern_source == 61e97998bf49c2d425563920b7e83e52b5ae57a6 ]]; then
    [[ $archive == runtime-7120P.tar ]] || fail 'Numerics candidate is qualified on 7120P only'
    step image-metadata-regression
    "$runtime/shared/bin/test-knc-mtmd" "$runtime/shared/tests/step3vl-mmproj.gguf"
fi
step modern-cli-startup
"$modern_engine" --describe > "$runtime/modern-identity.json"
"$modern_engine" --help > "$runtime/modern-help.txt"
if [[ -f $runtime/optimized-runtime-id.txt || -f $runtime/shared-runtime-id.txt ]]; then
    grep -q 'auto-resources-v1' "$runtime/modern-help.txt" || fail 'Automatic allocation capability missing'
fi
[[ $(cat "$runtime/modern-source.txt") == "$modern_source" ]] || fail 'modern source pin'
printf '%s\n' "$source" > "$runtime/build-passed.txt"
printf '%s\n' "$identity" > "$runtime/modern-runtime-passed.txt"
rm -f "$runtime/$archive"
printf 'PASS: native kernel suites, GGML numerical tests and CLI startup. Modern model inference and throughput require the separate hardware acceptance run.\n'
