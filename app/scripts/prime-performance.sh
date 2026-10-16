# Loaded only for an explicitly pinned, model-paired resident runner.
for switch in "$Q6_PANEL8" "$F16_CONV" "$F32_ATTN"; do
    [[ $switch == 0 || $switch == 1 ]] || fail 'Invalid matrix switch'
done
if [[ $PRIME_RUNNER == phi-prime-context-matrix-r2 ]]; then
    export GGML_KNC_Q6_PANEL8=$Q6_PANEL8 GGML_KNC_F16_CONV=$F16_CONV GGML_KNC_F32_ATTN=$F32_ATTN
else
    [[ $Q6_PANEL8$F16_CONV$F32_ATTN == 000 ]] || fail 'Matrix settings require the paired runtime'
fi
printf 'runner=%s\nq6_panel8=%s\nf16_conv=%s\nf32_attn=%s\n' "$PRIME_RUNNER" "$Q6_PANEL8" "$F16_CONV" "$F32_ATTN" > "$job/report/context-matrix.txt"
[[ $CORES == 61 && $PERFORMANCE_CAPABLE == 1 ]] || fail 'Unqualified performance profile'
[[ $IMAGE_CACHE_MIB =~ ^[0-9]+$ && $IMAGE_MAX_TOKENS =~ ^[0-9]+$ && $VISION_THREADS =~ ^[0-9]+$ ]] || fail 'Invalid performance settings'
((IMAGE_CACHE_MIB <= 512 && IMAGE_MAX_TOKENS <= 65536 && VISION_THREADS >= 60 && VISION_THREADS <= PROMPT_THREADS && VISION_THREADS % 60 == 0)) || fail 'Invalid performance bounds'
[[ $MQ_COLS == 1 || $MQ_COLS == 4 ]] || fail 'Invalid matrix column tile'
export GGML_KNC_MQ_COLS=$MQ_COLS
printf 'columns=%s\nimage_cache_mib=%s\nvision_threads=%s\n' "$MQ_COLS" "$IMAGE_CACHE_MIB" "$VISION_THREADS" >> "$job/report/shared-multi-quant.txt"

# A one-token warm-up can create only the generation pool (120 threads),
# while the first prompt expands it to 240. Verify each complete pool against
# the corresponding prefix of the same topology-derived CPU map.
verified_pool=0
phi_capture_affinity() {
    ((verified_pool < workers)) || return 0
    local pid=$1 path count=0 snapshot="$job/report/affinity-sample.tsv"
    : > "$snapshot"
    for path in /proc/"$pid"/task/*/status; do
        [[ -r $path ]] || return 0
        awk '/^Pid:/ {id=$2} /^Cpus_allowed_list:/ {print id "\t" $2}' "$path" >> "$snapshot" || return 0
        count=$((count+1))
    done
    ((count == THREADS || count == workers)) || return 0
    if awk -v cpus="$GOMP_CPU_AFFINITY" -v count="$count" '
        BEGIN {split(cpus,a," ");for(i=1;i<=count;i++)allowed[a[i]]=1}
        {if($2 !~ /^[0-9]+$/ || !allowed[$2] || seen[$2]++)bad=1}
        END {exit (bad || NR!=count)}' "$snapshot"; then
        cp "$snapshot" "$job/report/affinity-verified.tsv"
        verified_pool=$count
        affinity_verified=1
        affinity_retries=0
    else
        affinity_retries=$((affinity_retries+1))
        ((affinity_retries < 3)) || fail 'Resident worker placement differs from the verified CPU map'
    fi
}
