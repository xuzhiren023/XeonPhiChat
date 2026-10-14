# Decode3 runtime in Phi Chat 1.6.4

This version selects `knc-decode3-ecf5e24ef6c0a4f3` for all nine 7120P catalog models. It uses the established `61e9799` model formats and watchdog/base runtime, with the optimized resident executable in a separate pinned asset. The 3120A keeps its existing runtime; the producer's cross-built 5110P/3120A binaries are not enabled as native-qualified app targets.

The runtime optimizes quantized matrix processing, half-scale conversion, SwiGLU and softmax scheduling. The 7120P prompt pool uses 240 workers, rows 8 and columns 4. LFM2 decoders use 120 generation workers; the 8B Llama models use 240; other models keep their previous generation count. Thread affinity comes from the actual CPU topology and excludes the entire OS core. Priming verifies the initial generation pool and verifies the expanded prompt pool when it appears.

Vision sessions reserve a 64 MiB bounded cache inside the automatically allocated memory budget. Reusing the same image can skip vision encoding while retaining normal language-model ingestion. Cache entries belong to one model/projector/preprocessing session, include crop identity, and contain no conversational KV state. Stop/re-prime, model switch and shutdown discard them. Image detail is unchanged by default: no overview-only crop limit is enabled.

The native completion report retains encoder, image-ingestion and text-prefill times, cache hits/misses and cache bytes. The UI identifies a loaded candidate as **Optimized runtime decode3**. This label names the executable; it does not claim that every model/card combination has been benchmarked.

Existing model identity receipts are reused while paths, sizes and modification times match. Load, re-prime, image upload and SCP completion do not scan model/runtime/image files again for transfer SHA verification or perform checksum read-back. Setup/release asset admission still verifies pinned packages. The native vision library derives its internal cache key from the already-read image buffer; that key is not a transfer checksum check.

The exact producer identities are retained in `app/config/priming-runtime.json` and `assets/priming-runtime-build.json`. The decoder source, complete runtime patch and clean build recipe are under `tools/native-runner/decode3/`. The previous priming adapter source remains available under `tools/native-runner/priming/`. Existing installed app versions are separate.

## Validation

The PowerShell 5.1 host suite and changed shell-script syntax checks passed. The authorized 7120P application checks passed for LFM2.5 text and vision, image-cache reuse, different-image isolation, Stop/re-prime, model switch and cleanup. See [application timings and limits](VALIDATION.md). Producer numerical and synthetic text/image validation remains separate from app validation.

## Producer performance evidence

Five measured pairs after warmup used 91 prompt tokens, 16 timed decode evaluations, context 512 and batch 128. Median generation throughput changed from 3.046 to 6.156 tokens/s for LFM2.5 2.6B, and from 1.184 to 2.677 for Llama 3.3 8B. Prompt throughput changed from 7.335 to 15.208 and from 2.888 to 6.361, respectively. These are producer CLI measurements, separate from this app's automatic-context measurements.

The 2.6B comparison used 120 generation threads on both sides. The 8B comparison used baseline 120 and candidate 240, with 240 prompt threads for both: it compares tuned configurations. All output pairs matched. The requested generation targets of 10 and 4 tokens/s remain unmet. Long-context throughput and trained Q3/Q4 performance were not qualified by those short screens.
