# Context and matrix runtime in 1.6.10

The Windows package contains both decode3 and context-matrix-r2. The app selects context-matrix-r2 only for 7120P with Huihui Step3-VL 10B Abliterated Q5_K_M. LFM2.5-2.6B and all other 7120P models retain decode3; 3120A retains its existing runtime. The base source remains 61e97998bf49c2d425563920b7e83e52b5ae57a6. Exact archive/runner identities are in `assets/context-matrix-build.json` and the application pin.

| Pairing | Decode / prompt workers | Q6 panel8 | FP16 matrix | F32 attention matrix |
| --- | --- | --- | --- | --- |
| Huihui Step3 | 180 / 240, vision 240 | On | On | On |

F32 attention is not enabled globally: the producer measured a short-dot regression at 120 workers. Mixed quantizations, expert routing and unsupported layouts retain their original fallback implementations. Image resolution, crops, projector weights, KV precision and softmax are unchanged. Diagnostic tracing is disabled.

The producer also screened LFM2.5-2.6B with Q6/FP16 on and F32 off. The full app comparison used its automatic 131,072-token context and existing chat template: memory rebuilding added about 1.3 seconds before the first token, with no total-response improvement. That pairing is therefore not promoted.

## Conversation reuse

The resident process retains its actual evaluated token/image prefix. Unchanged images are indivisible. Ordinary transformers may trim changed suffixes when their memory API supports it. Recurrent/hybrid state is append-only; changed history safely rebuilds. Thinking preferences, chat switches, edits and token-boundary differences can reduce reuse or require a rebuild. The existing model chat templates remain unchanged, including removing completed historical reasoning; therefore recurrent LFM conversations may rebuild even for ordinary follow-ups. Stop/reload/model changes create a fresh worker. Nothing persists as a disk KV cache.

Statistics counts the full admitted prompt for context usage, shows reused tokens separately, and divides only newly evaluated tokens by prefill duration for input speed. Live prompt speed starts after the first positive position sample so a cached-prefix jump is not mistaken for processed tokens. Cached-image follow-ups do not display an image-processing stage unless image work is actually required.

## Producer evidence (inherited, not new app validation)

The optimization handoff reports 392 dense cases, 172,566 outputs and 131,072 FP16 products byte-exact, plus 140 history cases across 20 suites. Trained Step3 logits matched exact finite float values (not a signed-zero byte comparison) and three greedy follow-up tokens; trained 2.6B full dumps and five outputs matched byte-for-byte. Its five short 2.6B timing pairs measured median input 14.536 to 14.909 tokens/s and output 6.223 to 6.437 tokens/s. One controlled 448x336 image pair measured cold prefill 181.883 to 160.352 seconds and growing-history follow-up 41.088 to 4.847 seconds. These are limited producer measurements, not catalog-wide performance claims. Other cards and other trained models were not qualified for this pairing.

Application acceptance and installer checks are recorded separately in [VALIDATION.md](VALIDATION.md). Existing 1.6.9 installations remain available for rollback.

## Source rebuild

The exact adapter, prefix cache and matrix sources plus a portable clean rebuild recipe are retained in `tools/native-runner/context-matrix`. See `REBUILD.txt` there and the source hashes in `assets/context-matrix-build.json`. The recipe applies the retained decode3 patch to the pinned base source archive, builds both new assembly units into the CPU backend, and links through CMake. End users do not need this toolchain: the installer contains the qualified binaries. A newly rebuilt binary is not automatically native-qualified.

The producer completed the clean 7120P source rebuild on 2026-10-16: the runtime and eight diagnostics linked, all 214 source/compiler/linker/ELF checks passed, and 16,270 host prefix-policy checks passed under ASan/UBSan. Four hot instruction sections matched the delivered candidate objects. See `tools/native-runner/context-matrix/BUILD-VALIDATION.txt`. This is source/build validation; the fresh rebuilt binary was not run on the card or installed. The Windows installer continues to ship the exact R2 binary accepted by the app tests.
