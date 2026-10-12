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

The bundled bootstrap receipt identifies only the historical watchdog archive. It explicitly records `native_acceptance: false`. A modern runtime selection is written only after the new machine's native kernel, dispatch and CLI startup checks pass. Archive identity includes hardware profile, runtime ID, exact size and SHA-256. The 7120P payload contains the optimized and standard engines needed for model pairing.

Native binaries are prebuilt release dependencies. Their historical source pin is `03a8b80c7d502797325788f604248dd4aabdf5ef`; the modern llama.cpp pin is `6783b11fb0889d68d0046176b4cc92ceee1961b0`; GNU IMCI kernel package is 0.2.1. This repository does not rebuild the historical KNC cross-toolchain. End-user installation uses the verified archives, not a compiler. Native build provenance is retained in payload manifests and license notices.

`MIGRATION.json` records copied source paths and original hashes relative to the former repository, without personal host paths. Migration never deletes or renames the source application.

