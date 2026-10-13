# Shared runtime in 1.6.1

The 7120P default is now the fixed `61e9799` multimodal runtime. All nine catalog models use it; Step3-VL and LFM2.5-VL support image input. Gaston is labeled text only. The 3120A retains its `d57e0e6` text build. See [image/runtime contract](IMAGES.md), [exact new build provenance](../assets/multimodal-runtime-build.json), and [hardware validation](VALIDATION.md).

The following records the retained 1.5.7 build and its previous validation. It is not new multimodal acceptance.

# Shared runtime in 1.5.7

All six enabled dense models route to `shared/bin/phi-modern`, built against optimized llama.cpp commit `d57e0e6e4882445bc625aaee47f91db469f9fc22`. Its upstream base is `4413a192410fad1f054e9216114087a3e01527a0`. Mixed Q5_K_M, Q2_K and uniform Q5_K remain supported by the catalog; that earlier update did not enable vision or a new card profile.

Both 3120A and 7120P use exact cross-built MPSS GCC 5.1.1 binaries. ELF, ISA, ABI and host-reference checks passed. Native validation on 13 October 2026 covered a 7120P with LFM2.5 2.6B and Llama 3.3 8B Q5_K_M; the tested generation speeds were effectively unchanged from 1.5.6. Other models, full-length context quality and 3120A hardware remain unqualified. See [validation scope](VALIDATION.md). The UI displays the revision without inheriting the old TinyDolphin speed badge. Defaults are row tile 4, with 168 workers on 3120A and 180 on 7120P. Runtime placement reserves CPU 0's whole core using actual sibling topology. Context, batch and response allocation remain dynamic.

`phi-modern` is the private PhiChat-compatible driver linked to the new library, not the public `llama-simple` example. Its exact source and CMake file are retained under `tools/native-runner`. The binary's `--describe` reports the upstream base and a historical protocol version; the commit, binary SHA-256 and runtime ID identify the actual build. [Build inputs](../assets/upstream-runtime-build.json) and [composed payloads](shared-runtime-provenance.json) record those identities.

Setup verifies archive bytes, stages an isolated runtime and runs the shared graph oracle at row tiles 1/2/4/8, current `test-knc-dot`, 52 filtered backend cases, quantization and sampling checks, retained watchdog checks and CLI startup. Only then does it publish that card's runtime selection. No acceptance receipt is shipped. Model inference, numerical reset, automatic allocation, memory, temperature and actual affinity passed on the two tested 7120P models. Stop and subsequent conversation reuse passed with LFM2.5. These checks do not qualify every catalog model or another card profile. No card is accessed by the host tests or package composer.

Previous 1.5.6 and earlier runtime pins remain available by exact ID for restoration and rollback. The 1.5.6 installation and packages remain separate. Old speed results do not qualify the new binaries. Native archives contain the retained legacy watchdog/support files plus the new shared engine and its own tests/library.

## Build the payloads

Developer commands (Python 3.8+, PowerShell 5.1 and Bash); ordinary users only need the complete Windows ZIP and installed MPSS drivers:

```powershell
python tools/Build-UpstreamRuntime.py --base-assets C:/Build/phi153-payloads --evidence-archive C:/Build/knc-upstream-evidence.tar.gz
python tests/Test-SharedRuntime.py --bash 'C:/Program Files/Git/bin/bash.exe' --payloads
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-Host.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Build-Release.ps1
```

The evidence archive is pinned by SHA-256; its exact binaries are verified again individually. The composer writes fresh output only, removes inherited acceptance, verifies every generated member and updates manifests. The prior `Build-SharedRuntime.py` recipe documents the earlier 6783b11 export and is retained for historical rebuilds. `tools/native-runner/package-knc-profiles.sh` preserves the exact original compiler/link invocation and build-machine paths for reference; the CMake file is an alternative driver build entry point. Recompiling needs the exact source commit, pinned MPSS toolchain and SKU-specific settings. Different executable bytes need new hashes and separate qualification.

For developer staging-control comparisons, use `GGML_KNC_MQ=0` before starting the process. `--baseline-kernels` disables extended dot dispatch but does not disable staging reuse. It must not be described as a staging-off control. `--scalar-kernels` disables the optimized path.
