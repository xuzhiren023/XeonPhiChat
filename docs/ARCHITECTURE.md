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

## Preparation latency: resident worker

Version 1.6.2 moves model/context initialization into Load for the pinned 7120P runtime. A persistent PowerShell broker owns the guarded native worker and its exclusive card lease. It accepts local per-message requests, uploads prompt/media files and atomically publishes a request. Native length-prefixed frames carry admission, progress, output and completion separately. There is no new network listener.

Weights, projector and context remain resident. Tokenization and generation happen once in that process; attention and recurrent state are reset after each request. Stop terminates the owned worker and re-primes it while retaining the conversation. Model switching and app closure release the worker. Memory/thermal checks, heartbeat shutdown and SSH trust remain active. See [Priming](PRIMING.md) for behavior, source provenance and validation limits.

The baseline 1.6.1 image check spent 23.7 seconds in preparation, including 18.0 seconds inside a separate count/allocation process; generation then reported another 9.6 seconds of native initialization. Removing this repeated setup targets a few seconds from Send to input processing on a primed model. Hardware timing for 1.6.2 is pending; image encoding and long prompt ingestion remain separate costs.
