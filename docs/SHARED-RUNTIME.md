# Shared runtime in 1.5.4

Every enabled model routes to `shared/bin/phi-modern`. This includes the two uniform Q5_K models, mixed LFM/Llama Q5_K_M, Llama Q2_K and TinyDolphin. The engine supports dense `llama` and `lfm2`; Gaston `lfm2moe` and Step3-VL remain blocked. A model's required `shared-multi-quant-v1` capability prevents silent fallback to the former standard, Q5-only or historical worker.

| Card | Pinned upstream candidate | Evidence before app packaging |
| --- | --- | --- |
| 7120P | `knc-mq-a3ab0be8c35cb872acb6`, standalone export r4 | Native operator/graph checks; TinyDolphin Q5_K_M bitwise comparison with qualified r3 at row tile 8, 120 prompt / 180 decode threads |
| 3120A | `knc-mq-dc2cee6d8fb2420e1a06`, r3 | Cross-build and ISA audit; native validation remains pending |

The other chat also built a 5110P variant. Phi Chat currently has 3120A and 7120P hardware profiles; this release does not advertise 5110P app support. Exact executable, OpenMP library, parent archive and candidate identities are recorded in [shared-runtime-provenance.json](shared-runtime-provenance.json). Modern llama.cpp base: `6783b11fb0889d68d0046176b4cc92ceee1961b0`.

TinyDolphin/7120P uses the tested row-8 policy and shows the green performance check. Other 7120P models use row 4 and 180 prompt/decode workers; 3120A uses row 4 and 168 workers. These are conservative defaults, not measured optimal settings for every model. Old Q5-only performance badges and throughput measurements are not transferred to the new build. All selections display the shared-runtime label; the tooltip says "Using" only after Load succeeds. TinyDolphin's hash-verified GGUF uses ChatML with EOS ID 32000; its original prompt format is preserved.

Worker placement is derived from the card's actual sibling topology, reserving CPU 0's entire core and checking process affinity during generation. Context, batch and response allocation remain model/memory dependent. Guard, heartbeat, temperature, memory, Stop, strict SSH, workload ownership and isolated restoration remain required.

Setup checks the full archive hash, uploads it to an isolated directory and reads it back for verification. It executes the shared graph oracle for row tiles 1, 2, 4 and 8, operator tests, legacy guard-suite checks and actual shared CLI startup before recording that card's runtime selection. Packages contain no `modern-runtime-passed.txt` or inherited acceptance. Upstream numerical evidence does not replace a complete Phi Chat native model/Stop/thermal/memory acceptance run. No real services, network configuration, boot identity or card workload were changed while testing this installer repair.

## Rebuilding the release payloads

Developer packaging requires Python 3.8+ and the exact audited binary inputs; users do not need Python or a compiler. Preserve the original 1.5.3 payloads in a separate input folder and run:

```powershell
python tools/Build-SharedRuntime.py --base-assets C:/Build/phi153-payloads --build-3120a C:/Build/mq-3120a-r3 --build-7120p C:/Build/mq-export-r4 --libgomp C:/Build/libgomp.so.1
python tests/Test-SharedRuntime.py --bash 'C:/Program Files/Git/bin/bash.exe' --payloads
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-Host.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Build-Release.ps1
```

The composer pins every input, rejects unsafe tar members, removes the obsolete Q5-only engine and inherited acceptance markers, verifies every resulting member and updates the release/app manifests. Output paths must be fresh. Existing native archives and app installations are preserved separately.
