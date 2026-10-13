# Architecture

| Folder | Responsibility |
| --- | --- |
| `app/` | WPF frontend, PowerShell backend, C# helpers, card shell scripts and model/hardware profiles |
| `setup/` | Windows first-run setup, MPSS/network planning, SSH boot provisioning and rollback |
| `assets/` | Immutable native and optimized model manifests; ignored `payloads/` holds local build inputs |
| `tests/`, `app/tests/`, `setup/tests/` | Host fixtures and inherited application tests |
| `tools/` | Host validation and verified ZIP packaging |
| `licenses/` | Third-party notices copied with the runtime |
| `dist/` | Generated release ZIPs and SHA-256 files; ignored by Git |

The UI starts isolated backend PowerShell workers. Workers perform SSH transport, hardware validation, guarded native execution and model preparation. Each chat locks its model at the first prompt. Stop interrupts the current response; the history and composer remain usable. Resource allocation uses model metadata and card memory. No CPU fallback is used for inference.

Installed `app/config/connection.yaml` is generated locally. Relative paths keep application data, credentials and runtime backup inside the installation. Only installed system tools (MicInfo, SSH/SCP and tar) can use external paths. Their presence is checked at first use. No monolith path or previous runtime acceptance is imported.

The bundled bootstrap receipt identifies only the historical watchdog archive. It explicitly records `native_acceptance: false`. A modern runtime selection is written only after the new machine's native kernel, dispatch and CLI startup checks pass. Archive identity includes hardware profile, runtime ID, exact size and SHA-256. Both hardware payloads contain the shared multi-quant engine used by all supported chat models; retained legacy binaries support the guard/regression suite. A missing shared engine cannot silently select an older engine. Previous runtime pins remain available for identifying existing installations.

Native binaries are prebuilt release dependencies. Their historical source pin is `03a8b80c7d502797325788f604248dd4aabdf5ef`; the 7120P modern pin is `61e97998bf49c2d425563920b7e83e52b5ae57a6` plus its exact metadata-fix patch, while 3120A retains `d57e0e6e4882445bc625aaee47f91db469f9fc22`; GNU IMCI kernel package is 0.2.1. This repository does not rebuild the historical KNC cross-toolchain. End-user installation uses the verified archives, not a compiler. Native build provenance is retained in payload manifests and license notices.

`MIGRATION.json` records copied source paths and original hashes relative to the former repository, without personal host paths. Migration never deletes or renames the source application.


Protocol v2 attaches bounded image references to individual user turns. The session cache owns normalized PNGs; workers verify IDs/hashes and stage only images retained by the final prompt. Projector identity, memory accounting and ordered media markers are specific to the pinned Step3 and LFM2-VL adapters. See [IMAGES.md](IMAGES.md).

## Preparation latency: proposed resident worker

This is a design recommendation, not a feature in 1.6.1. The current Load action stages verified weights on the card. Every Send then starts one native process to count expanded prompt tokens and allocate context, destroys it, and starts another process to generate. Repeated sends still incur this cost even with an allocation receipt. A one-shot warm-up cannot retain resources after its process exits.

The 1.6.1 7120P image check spent 23.7 seconds before generation launch. About 18.0 seconds were inside the count/allocation subprocess; the remaining 5.7 seconds included PowerShell startup, health/identity checks, SSH/SCP and report handling. Generation then reported another 9.6 seconds for native initialization, which includes tokenization and image preparation as well as model/context setup. These phases must be measured separately from image encoding and first-token latency.

The recommended runtime change is an optional resident mode in the existing pinned runner, using the existing SSH connection rather than a new network service. Load should initialize the decoder, optional matching projector, context and reusable batch, then return READY with actual allocation and model/runtime/card identities. Send should tokenize, validate positions, choose the remaining output budget and generate within that same process. It should not launch a second count process or preprocess images twice.

Retain model/projector/context allocations between requests, but clear attention and recurrent/convolution state and release request-owned tokens, image bitmaps and chunks. Continue replaying the complete retained conversation initially; prompt-prefix caching is a separate optimization. Context/batch changes may recreate context while keeping weights. A model switch, card boot change, worker exit or application closure must release or invalidate the resident allocation. Memory planning must account for the already allocated worker exactly once.

The host needs a persistent backend worker with framed, versioned requests/responses and a live readiness state. Keep the card lease and health/heartbeat monitoring for its lifetime. Stop should cancel the current request and reset its state; image-encoder cancellation may require terminating and re-priming the worker in the background while retaining the conversation. Plain generated text must never be parsed as protocol control data.

The target is a few seconds from Send to tokenization/prefill on an already-ready worker, measured separately for text and image requests. This has not been achieved or timed by 1.6.1. Qualification must compare fresh versus reused worker results, consecutive independent chats, images, Stop/retry, model switches and memory release. The runtime chat confirmed that the present runner has no resident mode; adding it requires a new pinned native build and app transport support. Encoding a picture and processing a long prompt still require their normal compute time.
