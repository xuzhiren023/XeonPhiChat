# Included only in the hash-pinned optimized runtime. Sourced after worker
# validation; fail(), runtime, job and validated thread counts are supplied.
[[ $CORES == 61 ]] || fail 'Optimized runtime requires the qualified 7120P topology'
[[ $(cat "$runtime/optimized-runtime-id.txt") == "$MODERN_RUNTIME_ID" ]] || fail 'Optimized runtime identity mismatch'
unset BP_KNC_CPUS BP_Q5_SPECIALIZE GOMP_CPU_AFFINITY OMP_PLACES KMP_AFFINITY OMP_THREAD_LIMIT
export OMP_DYNAMIC=FALSE OMP_NESTED=FALSE OMP_MAX_ACTIVE_LEVELS=1
workers=$THREADS
((PROMPT_THREADS <= workers)) || workers=$PROMPT_THREADS
topology="$job/report/topology.tsv"
printf 'allowed\t%s\n' "$(awk '/^Cpus_allowed_list:/ {print $2}' /proc/self/status)" > "$topology"
for directory in /sys/devices/system/cpu/cpu[0-9]*; do
    cpu=${directory##*cpu}
    [[ $cpu =~ ^[0-9]+$ ]] || continue
    [[ ! -f $directory/online || $(cat "$directory/online") != 0 ]] || continue
    printf 'cpu\t%s\t%s\n' "$cpu" "$(cat "$directory/topology/thread_siblings_list")" >> "$topology"
done
GOMP_CPU_AFFINITY=$(awk -v workers="$workers" -f "$runtime/optimized/knc-affinity.awk" "$topology") || fail 'Cannot derive a verified 7120P CPU map'
export GOMP_CPU_AFFINITY OMP_PROC_BIND=TRUE OMP_NUM_THREADS="$workers" BP_Q5_SPECIALIZE=1
printf '%s\n' "$GOMP_CPU_AFFINITY" > "$job/report/requested-affinity.txt"
affinity_verified=''; affinity_retries=0
phi_capture_affinity() {
    [[ -z $affinity_verified ]] || return 0
    local pid=$1 path count=0 snapshot="$job/report/affinity-sample.tsv"
    : > "$snapshot"
    for path in /proc/"$pid"/task/*/status; do
        [[ -r $path ]] || return 0
        awk '/^Pid:/ {id=$2} /^Cpus_allowed_list:/ {print id "\t" $2}' "$path" >> "$snapshot" || return 0
        count=$((count+1))
    done
    ((count >= workers)) || return 0
    if awk -v cpus="$GOMP_CPU_AFFINITY" -v workers="$workers" '
        BEGIN {n=split(cpus,a," ");for(i=1;i<=n;i++)allowed[a[i]]=1}
        {if($2 !~ /^[0-9]+$/ || !allowed[$2] || seen[$2]++)bad=1}
        END {exit (bad || NR!=workers)}' "$snapshot"; then
        cp "$snapshot" "$job/report/affinity-verified.tsv"
        affinity_verified=1
    else
        affinity_retries=$((affinity_retries+1))
        ((affinity_retries < 3)) || fail 'Native worker placement differs from the verified CPU map'
    fi
}
