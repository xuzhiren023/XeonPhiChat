#!/usr/bin/env bash
set -euo pipefail
# All arguments/settings originate in the Windows launcher, never model output.
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ $# == 2 && $1 =~ ^/root/knc-phase3-run-[A-Za-z0-9-]+$ && $2 =~ ^/root/knc-chat-[a-f0-9]+$ ]] || fail 'Invalid runtime/job path'
runtime=$1
job=$2
[[ $(uname -m) == k1om ]] || fail 'Native K1OM required; no host inference fallback'
mkdir "$job/report"
model_pid=''
filter_pid=''
lock_owned=''
cleanup() {
    local rc=$?
    trap - EXIT
    if [[ -n $model_pid ]] && kill -0 "$model_pid" 2>/dev/null; then
        kill "$model_pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$model_pid" 2>/dev/null || true
        wait "$model_pid" 2>/dev/null || true
    fi
    if [[ -n $filter_pid ]]; then
        kill "$filter_pid" 2>/dev/null || true
        wait "$filter_pid" 2>/dev/null || true
    fi
    for input in "$job"/inputs/*; do
        [[ $input =~ /inputs/[a-f0-9]{32}$ ]] || continue
        rm -f "$input/prompt.txt" "$input"/image-[0-3].png
        rmdir "$input" 2>/dev/null || true
    done
    rm -f "$job/request" "$job/request.pending"
    rm -f "$job/prime/bin/phi-prime" "$job/prime/lib/libgomp.so.1"
    printf 'exit_code=%s\n' "$rc" > "$job/report/exit-code.txt"
    if [[ -n $lock_owned ]] && [[ $(cat /tmp/knc-phase3-workload.lock/phi-chat-owner 2>/dev/null) == "$LOCK_TOKEN" ]]; then
        rm -f /tmp/knc-phase3-workload.lock/worker-pid /tmp/knc-phase3-workload.lock/phi-chat-owner
        rmdir /tmp/knc-phase3-workload.lock
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT
# shellcheck source=/dev/null
source "$job/settings.sh"
[[ ${LOCK_TOKEN:-} =~ ^[a-f0-9]{32}$ ]] || fail 'Invalid workload lock token'
[[ $(cat /tmp/knc-phase3-workload.lock/phi-chat-owner 2>/dev/null) == "$LOCK_TOKEN" ]] || fail 'Model staging lock ownership lost'
lock_owned=1
printf '%s\n' "$$" > /tmp/knc-phase3-workload.lock/worker-pid
# shellcheck source=scripts/elf-check.sh
source "$job/elf-check.sh"
[[ $SOURCE_COMMIT =~ ^[a-f0-9]{40}$ && $(cat "$runtime/build-passed.txt") == "$SOURCE_COMMIT" ]] || fail 'Accepted runtime source identity missing'
engine="$runtime/llama/main"
if [[ ${RUNTIME_FAMILY:-historical-knc} == modern-knc ]]; then
    [[ ${MODERN_RUNTIME_ID:-} =~ ^phichat14[012]-modern-[a-f0-9]{16}$ ]] || fail 'modern runtime identity'
    [[ $(cat "$runtime/modern-runtime-passed.txt") == "$MODERN_RUNTIME_ID" ]] || fail 'modern runtime startup receipt'
    [[ $(cat "$runtime/modern-source.txt") == "${MODERN_SOURCE_COMMIT:-6783b11fb0889d68d0046176b4cc92ceee1961b0}" ]] || fail 'modern engine source'
    engine="$runtime/llama/phi-modern"
fi
source "$job/engine-llama-cli-v1.sh"
phi_select_engine
[[ $MODEL_PATH =~ ^/root/knc-phase3-run-[A-Za-z0-9-]+/(model\.gguf|models/[a-z0-9_.-]+\.gguf)$ ]] || fail 'Invalid model path'
for value in "$THREADS" "$PROMPT_THREADS" "$CORES" "$PREDICT" "$BATCH" "$MODEL_BYTES" "$RUNTIME_ADMIT_MIB" "$RUNTIME_LIMIT_MIB" "$MEMORY_STOP_MIB" "$SEED" "$CONTEXT"; do
    [[ $value =~ ^[0-9]+$ ]] || fail 'Non-numeric workload setting'
done
case "$CORES:$THREADS" in 57:56|57:112|57:168|57:224|61:60|61:120|61:180|61:240) ;; *) fail 'Invalid generation threads for this profile';; esac
case "$CORES:$PROMPT_THREADS" in 57:56|57:112|57:168|57:224|61:60|61:120|61:180|61:240) ;; *) fail 'Invalid prompt threads for this profile';; esac
((PREDICT >= 0 && PREDICT < CONTEXT && BATCH >= 1 && BATCH <= CONTEXT && MEMORY_STOP_MIB >= 256)) || fail 'Invalid workload limits'
((CONTEXT >= 128 && CONTEXT <= 2147483647)) || fail 'Unsupported context'
[[ $RUN_MODE == generate || $RUN_MODE == check ]] || fail 'Invalid workload mode'
# MODEL_PATH is restricted above to an ASCII path without whitespace. MPSS
# BusyBox ls -ln provides metadata without reading the GGUF.
# shellcheck disable=SC2012
[[ -f $MODEL_PATH && $(LC_ALL=C ls -ln "$MODEL_PATH" | awk '{print $5}') == "$MODEL_BYTES" ]] || fail 'Model absent or incomplete'

unset LD_LIBRARY_PATH LD_PRELOAD OMP_THREAD_LIMIT OMP_NUM_THREADS
# 1.4.3.3: enable the supplied Q5 candidate only in its pinned historical
# engine. Modern LFM/Llama binaries and their dispatch remain unchanged.
unset PHI_KNC_Q5_MODE PHI_KNC_F32_MODE PHI_KNC_EXTENDED PHI_KNC_TRACE
if [[ ${RUNTIME_FAMILY:-historical-knc} != modern-knc && -f $runtime/q5-repair.json ]]; then
    case $(cat "$runtime/runtime-id.txt") in
        phichat142-modern-3554c44c1f51ed57|phichat142-modern-40dbb7531d2e5096|phichat142-modern-346789f47a328478|phichat142-modern-3673c2e612bc757d|phichat142-modern-9610d4c7df2513c6) ;;
        *) fail 'Unrecognized Q5 repair runtime';;
    esac
    export PHI_KNC_Q5_MODE=repair PHI_KNC_F32_MODE=vendor PHI_KNC_EXTENDED=0
    printf 'q5_mode=repair\nf32_mode=vendor\nextended_kquants=historical\ntrace=off\n' > "$job/report/q5-mode.txt"
fi
if [[ ${RUNTIME_FAMILY:-historical-knc} == modern-knc ]]; then
    unset GOMP_CPU_AFFINITY OMP_PROC_BIND OMP_PLACES
    export OMP_DYNAMIC=FALSE OMP_NESTED=FALSE OMP_MAX_ACTIVE_LEVELS=1
fi
phi_configure_engine
# Native guard retains wall time/thermal protection; no CPU-time quota.
ulimit -c 0
ulimit -a > "$job/report/process-limits.txt"
[[ $(ulimit -t) == unlimited ]] || fail 'Inherited CPU-time limit is finite; inspect process-limits.txt before inference'
cat /proc/self/status > "$job/report/worker-status.txt"
check_elf "$engine"
read_memory() {
    local snapshot
    snapshot=$(awk -f "$job/memory-info.awk" /proc/meminfo) || fail 'Cannot read memory telemetry'
    read -r free available cache_credit <<< "$snapshot"
    [[ $free =~ ^[0-9]+$ && $available =~ ^[0-9]+$ && $cache_credit =~ ^[0-9]+$ ]] || fail 'Invalid memory telemetry'
}
read_memory
((available >= (RUNTIME_ADMIT_MIB + MEMORY_STOP_MIB) * 1024)) || fail "Insufficient allocatable GDDR: $((available / 1024)) MiB; runtime + reserve needs $((RUNTIME_ADMIT_MIB + MEMORY_STOP_MIB)) MiB"
cat /proc/meminfo > "$job/report/memory-before.txt"
printf 'generation_threads=%s\nprompt_threads=%s\nbatch=%s\ncontext=%s\nmode=%s\nmemory_mode=shared_mmap\n' "$THREADS" "$PROMPT_THREADS" "$BATCH" "$CONTEXT" "$RUN_MODE" > "$job/report/settings.txt"
printf 'runtime_family=%s\nmodern_test_mode=%s\nGOMP_CPU_AFFINITY=%s\n' "${RUNTIME_FAMILY:-historical-knc}" "${MODERN_TEST_MODE:-none}" "${GOMP_CPU_AFFINITY:-unset}" >> "$job/report/settings.txt"
printf 'engine=%s\nengine_variant=%s\n' "$engine" "${MODERN_ENGINE_VARIANT:-standard}" >> "$job/report/settings.txt"
printf 'epoch,memfree_kib,vmrss_kib,vmhwm_kib,available_kib,cache_credit_kib,model_mapped_kib,model_rss_kib,additional_rss_kib\n' > "$job/report/memory.csv"
# This pinned CLI defaults to MAP_SHARED, PROT_READ. Its trace logger otherwise
# writes full prompts to main.log; discard those traces in this unique job only.
# Keep LOG_TEE on stderr for loader diagnostics and real llama_print_timings.
cd "$job"
ln -s /dev/null main.log
ln -s /dev/null llama.log
# The host verified the pinned archive before SCP. No card hash utility is required.
check_elf "$job/prime/lib/libgomp.so.1"
engine="$job/prime/bin/phi-prime"
check_elf "$engine"
args=(-m "$MODEL_PATH" -c "$CONTEXT" -b "$BATCH" -t "$THREADS" -tb "$PROMPT_THREADS" -n 0 --serve "$job")
if [[ $PROJECTOR_PATH != none ]]; then
    [[ $PROJECTOR_PATH == "${MODEL_PATH%.gguf}-projector.gguf" && $PROJECTOR_SHA256 =~ ^[a-f0-9]{64}$ ]] || fail 'Invalid primed projector pairing'
    [[ $(cat "$PROJECTOR_PATH.identity") == "$PROJECTOR_SHA256" && $(LC_ALL=C ls -ln "$PROJECTOR_PATH" | awk '{print $5}') == "$PROJECTOR_BYTES" ]] || fail 'Primed projector is absent or changed'
    args+=(--mmproj "$PROJECTOR_PATH")
fi
if [[ -n ${STOP_TOKEN_IDS:-} ]]; then
    [[ $STOP_TOKEN_IDS =~ ^[0-9]+(,[0-9]+)*$ ]] || fail 'Invalid stop tokens'
    IFS=',' read -r -a stop_ids <<< "$STOP_TOKEN_IDS"
    for stop_id in "${stop_ids[@]}"; do args+=(--stop-token "$stop_id"); done
fi
"$engine" "${args[@]}" 2> "$job/report/timing.txt" &
model_pid=$!
mapping_seen=''
printf 'PHICHAT_PROGRESS init 0 0 0\n' >&2
while kill -0 "$model_pid" 2>/dev/null; do
    phi_capture_affinity "$model_pid"
    # smaps counts the model's mapped pages in RSS. Subtract them once from
    # process RSS: those physical pages already belong to the RAM-backed file.
    if ! map_info=$(awk -v path="$MODEL_PATH" -f "$job/model-map.awk" "/proc/$model_pid/smaps" 2>/dev/null); then
        if ! kill -0 "$model_pid" 2>/dev/null || grep -q '^State:.*Z' "/proc/$model_pid/status" 2>/dev/null; then break; fi
        fail 'Cannot read model mapping telemetry; no unmonitored copy-mode fallback'
    fi
    read -r mapped model_rss rss unsafe_maps <<< "$map_info"
    for value in "$mapped" "$model_rss" "$rss" "$unsafe_maps"; do
        [[ $value =~ ^[0-9]+$ ]] || fail 'Invalid model mapping telemetry'
    done
    ((unsafe_maps == 0 && model_rss <= rss)) || fail 'Model mapping is not read-only/shared, or RSS telemetry is inconsistent'
    # smaps is a stream and can restart as VMAs split during allocation. Use
    # the kernel's process counters for the total, with one bounded file credit.
    counters=$(awk '$1 == "VmRSS:" {r=$2} $1 == "VmHWM:" {h=$2} END {if (r != "" && h != "") print r, h}' "/proc/$model_pid/status" 2>/dev/null || true)
    if [[ ! $counters =~ ^[0-9]+[[:space:]][0-9]+$ ]]; then
        if ! kill -0 "$model_pid" 2>/dev/null || grep -q '^State:.*Z' "/proc/$model_pid/status" 2>/dev/null; then break; fi
        fail 'Cannot read process memory counters'
    fi
    read -r rss hwm <<< "$counters"
    model_cap_kib=$(((MODEL_BYTES + 4095) / 4096 * 4))
    ((model_rss <= model_cap_kib)) || model_rss=$model_cap_kib
    ((model_rss <= rss)) || model_rss=$rss
    if ((mapped * 1024 >= MODEL_BYTES * 9 / 10)) && [[ -z $mapping_seen ]]; then
        mapping_seen=1
        cat "/proc/$model_pid/maps" > "$job/report/model-maps.txt" 2>/dev/null || true
        printf 'PASS: read-only shared model mapping observed\n' > "$job/report/model-mapping.txt"
    fi
    additional_rss=$((rss - model_rss))
    read_memory
    printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$(date +%s)" "$free" "$rss" "${hwm:-0}" "$available" "$cache_credit" "$mapped" "$model_rss" "$additional_rss" >> "$job/report/memory.csv"
    ((available >= MEMORY_STOP_MIB * 1024)) || fail "Low allocatable GDDR: $((available / 1024)) MiB; reserve $MEMORY_STOP_MIB MiB"
    ((additional_rss <= RUNTIME_LIMIT_MIB * 1024)) || fail "Additional runtime RSS $((additional_rss / 1024)) MiB exceeds this card's $RUNTIME_LIMIT_MIB MiB budget"
    if [[ -n $mapping_seen && ${affinity_verified:-} == 1 ]]; then
        printf 'ready\n' > "$job/report/priming-guard-ready.txt"
    fi
    printf 'PHICHAT_PROGRESS init 0 %s %s\n' "$available" "$additional_rss" >&2
    sleep 1

done
rc=0
wait "$model_pid" || rc=$?
model_pid=''
((rc == 0)) || exit "$rc"
cat /proc/meminfo > "$job/report/memory-after.txt"
