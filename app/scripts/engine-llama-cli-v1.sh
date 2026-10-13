#!/usr/bin/env bash
# Adapter v1: validated worker settings in; engine path and Bash argv array out.
# No eval, user-selected executable, host fallback, or model loading here.
phi_select_engine() {
    case ${RUNTIME_FAMILY:-historical-knc} in
        historical-knc)
            [[ ${MODERN_ENGINE_VARIANT:-historical} == historical ]] || fail 'Invalid historical engine pairing'
            engine="$runtime/llama/main" ;;
        modern-knc)
            [[ ${MODERN_RUNTIME_ID:-} =~ ^phichat14[012]-modern-[a-f0-9]{16}$ ]] || fail 'modern runtime identity'
            [[ $(cat "$runtime/modern-runtime-passed.txt") == "$MODERN_RUNTIME_ID" ]] || fail 'modern runtime startup receipt'
            [[ $(cat "$runtime/modern-source.txt") == "${MODERN_SOURCE_COMMIT:-6783b11fb0889d68d0046176b4cc92ceee1961b0}" ]] || fail 'modern engine source'
            case ${MODERN_SOURCE_COMMIT:-6783b11fb0889d68d0046176b4cc92ceee1961b0} in
                6783b11fb0889d68d0046176b4cc92ceee1961b0|d57e0e6e4882445bc625aaee47f91db469f9fc22) ;;
                *) fail 'Unsupported modern source revision';;
            esac
            engine="$runtime/llama/phi-modern"
            case ${MODERN_ENGINE_VARIANT:-standard} in
            standard)
                [[ ${MODERN_SOURCE_COMMIT:-6783b11fb0889d68d0046176b4cc92ceee1961b0} == 6783b11fb0889d68d0046176b4cc92ceee1961b0 ]] || fail 'Rebased models require the shared engine'
                ;;
            shared)
                [[ -f $runtime/shared-runtime-id.txt && $(cat "$runtime/shared-runtime-id.txt") == "$MODERN_RUNTIME_ID" ]] || fail 'Shared runtime identity'
                engine="$runtime/shared/bin/phi-modern"
                ;;
            optimized)
                [[ -f $runtime/optimized-runtime-id.txt ]] || fail 'Optimized model runtime is not installed'
                [[ $(cat "$runtime/optimized-runtime-id.txt") == "$MODERN_RUNTIME_ID" ]] || fail 'optimized runtime identity'
                engine="$runtime/optimized/bin/phi-modern"
                ;;
            *) fail 'Unknown model runtime pairing';;
            esac
            ;;
        *) fail 'Unsupported engine adapter runtime family' ;;
    esac
}
phi_configure_engine() {
    unset BP_KNC_CPUS BP_Q5_SPECIALIZE GGML_KNC_MQ GGML_KNC_MQ_ROWS
    if [[ $engine == "$runtime/shared/bin/phi-modern" ]]; then
        source "$runtime/shared/configure.sh"
    elif [[ $engine == "$runtime/optimized/bin/phi-modern" ]]; then
        source "$runtime/optimized/configure.sh"
    fi
}
phi_capture_affinity() { :; }

phi_build_engine_args() {
    grep -q -- '--no-mmap' "$job/report/main-help.txt" || fail 'Accepted runtime has no mmap support; no weight-copy fallback'
    args=(-m "$MODEL_PATH" -c "$CONTEXT" -b "$BATCH" -t "$THREADS" -tb "$PROMPT_THREADS"
          -ngl 0 --seed "$SEED" --temp 0 --no-display-prompt --log-enable -f "$job/prompt.txt")
    if [[ ${RUNTIME_FAMILY:-historical-knc} == modern-knc ]] && ! grep -q 'auto-resources-v1' "$job/report/main-help.txt"; then
        # Do not silently clamp requests to the old binary's hard-coded limits.
        ((CONTEXT <= 2048 && BATCH <= 128 && PREDICT <= 512)) || fail 'Installed runner has fixed limits. Build and qualify the auto-resources-v1 runtime before using automatic allocation.'
    fi
    if [[ -n ${STOP_TOKEN_IDS:-} ]]; then
        [[ ${RUNTIME_FAMILY:-historical-knc} == modern-knc && $STOP_TOKEN_IDS =~ ^[0-9]+(,[0-9]+)*$ ]] || fail 'Invalid additional stop IDs'
        IFS=',' read -r -a stop_ids <<< "$STOP_TOKEN_IDS"
        ((${#stop_ids[@]} <= 16)) || fail 'Too many stop IDs'
        for stop_id in "${stop_ids[@]}"; do args+=(--stop-token "$stop_id"); done
    fi
    if [[ $RUN_MODE == check ]]; then
        grep -q -- '--verbose-prompt' "$job/report/main-help.txt" || fail 'Pinned runtime lacks native prompt counting'
    else
        grep -q -- '--print-token-count' "$job/report/main-help.txt" || fail 'Pinned runtime lacks progress counters'
        args+=(--print-token-count 1)
        if [[ ${RUNTIME_FAMILY:-historical-knc} == modern-knc ]]; then
            case ${MODERN_TEST_MODE:-none} in
                none|optimized) ;;
                scalar) args+=(--scalar-kernels) ;;
                baseline) args+=(--baseline-kernels) ;;
                trace) args+=(--trace-kernels) ;;
                validate) mkdir "$job/report/validation"; args+=(--validate-state "$job/report/validation" --cycles 3 --trace-kernels) ;;
                *) fail 'Unknown acceptance mode' ;;
            esac
        fi
    fi
}
