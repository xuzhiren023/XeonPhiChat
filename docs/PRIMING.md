# Resident priming in 1.6.3

Load now initializes the selected 7120P model, its matching projector when present, and the automatically sized context/batch. A small decoder warm-up runs before the UI says **Primed**. All nine 7120P catalog models use this path, including Gaston (text only), LFM2.5-VL and Step3-VL. The 3120A keeps its existing runtime and loading behavior.

After priming, Send submits the prompt and retained images to that running model. Token counting and generation share the same process and prepared input; the previous count-process/load-process pair is removed. On the tested 7120P, short LFM2.5-VL text requests reached input processing in 2.6–3.3 seconds from Send, including after Stop/re-prime. A 120×80 image began vision processing in 2.6 seconds. These measurements describe preparation latency, not time to finish an answer. Picture encoding and long prompt ingestion still require compute time; priming does not make Step3's vision encoder run instantly.

Stop interrupts the native response, confirms cleanup and starts priming again in the background. The conversation and editable composer remain available; Send returns when the model is ready. Switching or reloading models shuts down the previous resident worker first. Closing the app or losing its connection stops the owned workload through the existing heartbeat guard. Other applications' card workloads are never taken over.

The worker retains weights, the optional projector, context and reusable batch. It clears both attention and recurrent/convolution state after each response, and frees each request's media objects. Each request replays its own retained conversation; no prompt-prefix cache is shared between chats. The context is selected at Load from the model capacity and available card memory, with a reserve for supported image inputs. Reload recalculates this allocation. Output length is chosen from the remaining context after native tokenization.

The app owns one resident worker. Keeping a model primed intentionally keeps its context and weights resident until model reload, app closure or disconnect. This is different from an unreachable allocation: the worker has an explicit owner, live status and shutdown path. Stop currently uses termination and re-priming because the pinned image backend does not provide reliable cooperative cancellation.

## Implementation and verification

`app/lib/PrimeClient.ps1` queues local requests. `app/lib/Priming.ps1` owns the persistent broker and guarded SSH process. `app/scripts/prime-worker.sh` maintains card memory/mapping/affinity checks. The native adapter in `tools/native-runner/priming/knc.cpp` adds `--serve DIRECTORY` to the pinned `61e9799` base plus its existing metadata fix. The native input directory is private to that worker; uploads become visible through an atomic request-file rename. Length-prefixed `PHIP1` frames keep model bytes separate from control messages, including UTF-8 fragments.

Version 1.6.3 verifies the pinned archive once on Windows before SCP, checks transferred size, then checks K1OM ELF headers on the card. It requires no card-side SHA utility. Image attachment hashes are recorded once at import; image transfers use metadata checks without rehashing or read-back.

The additional `prime-7120P.tar` asset contains the runner and its OpenMP library. Existing runtime archives and older installed versions remain unchanged. Exact source, library and executable identities are retained in `assets/priming-runtime-build.json` and `app/config/priming-runtime.json`. The source ZIP includes the adapter and a full cross-build recipe; end users need no compiler or Python.

Offline checks cover the PowerShell broker, framing, UI readiness and Stop/re-prime transitions. Synthetic x86 fixtures compare resident output against fresh-process output, independent consecutive requests, image/text transitions, rejected input recovery and memory stability. These are not native Phi performance measurements.

The user authorized hardware testing for 1.6.3. Measurements use the real Windows backend and its guarded native worker; see [validation](VALIDATION.md) for the tested models and lifecycle checks. Step3 and the other catalog models were not re-benchmarked in this hotfix.
