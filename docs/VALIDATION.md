# Validation

## 1.6.0: images and the shared multimodal runtime

The 7120P payload uses source `61e97998bf49c2d425563920b7e83e52b5ae57a6` plus the retained GCC metadata fix, executable SHA-256 `e3366b50052818a7cc223f57b7b69f55316e5cd93e3ca9b67b413a849b235d54`. All eight catalog models resolve to this exact shared engine on 7120P. The 3120A retains its previous pinned text engine. The producer's numerical replay and small vision fixtures are inherited evidence, separate from the trained-model checks below.

The Windows PowerShell 5.1 host suite passed, including actual WPF attachment controls, image normalization, thumbnail removal, image-only input, history image ordering/trimming, stored drafts, offline cleanup, context/Stop behavior and model/runtime pairing. The UI was rendered and inspected. The file-picker/drop entry point was exercised through the real controls; a physical OS drag gesture was not automated. The shared-runtime package check passed 114 checks, including exact archive/binary identities, K1OM ELF headers, affinity configuration and the required metadata patch. A focused follow-up check covered the new Processing images status.

The first trained Step3 run exposed an obsolete projector conversion: its downsamplers used old tensor names. The release pins the structurally compatible JamePeng conversion and its locally generated Q6_K artifact. Both the complete decoder and projector were hashed before loading. No hardware reset or network/MPSS reconfiguration was used.

On 13 October 2026, the complete Step3-VL Q5_K_M decoder plus Q6_K projector returned **Blue** for a 120-by-80 blue image on the 7120P. Native counting expanded the request to 208 tokens/positions. The run used 2,048 context, batch 32 and verified 180-worker affinity. It generated 37 tokens at 1.181 tokens/s; first stream byte was 494.4 seconds after generation launch, plus 29.2 seconds of preparation. The encoder/prefill dominates the wait. Peak temperature was 68 C, peak additional RSS was 2,779.6 MiB, and minimum available memory was 4,503.1 MiB. The decoder mapping was counted once. Native unloading returned process RSS to about 82 MiB, and the job released its card lease and transient images.

The earlier structurally compatible Q8 trial was stopped during encoding, without a completed response. Its dominant vision matrices use generic kernels in this runtime; Q6_K uses supported optimized matrix paths. This does not establish an exact Q8/Q6 speedup or broad visual accuracy. General photographs, OCR, long contexts and other cards are not qualified by the small color-image check.

An automatic follow-up retained the original image and counted 227 tokens/positions in a 6,048-token context with batch 128. Stop interrupted its image encoder, returned `preserve_ready=true`, removed transient images and released the lease. A subsequent text request using the same readiness completed without reloading (24 tokens at 1.131 tokens/s, deliberately short). These exercise cancellation and continuation; the automatic follow-up was not run to a completed image answer.

Gaston completed short arithmetic conversations on the same runtime with automatic allocation: 111,200 context tokens, batch 128 and 180 workers. The final run returned **14** for 6 plus 8, generating 58 tokens at 3.521 tokens/s. First stream byte arrived after 21.4 seconds, plus 23.4 seconds of preparation. Peak native RSS was 6,955.8 MiB, peak additional RSS 1,403.2 MiB, minimum free memory 7,710.9 MiB and peak temperature 61 C. This validates allocation and short generation, not full-context quality.

These runs exposed transient duplicate/overlapping mappings while Linux streamed `smaps` during allocation. The worker now reads total resident memory from the kernel's `VmRSS`, deduplicates model mapping ranges and caps model credit at its page-rounded file size. Unsafe mappings remain rejected. The final native run and a repeated-mapping regression confirm that this bookkeeping no longer inflates reported memory or causes a false allocation stop.

## 1.5.7: optimized llama.cpp d57e0e6

Both supported profiles package the exact MPSS GCC 5.1.1 cross-built `phi-modern` runner linked against `d57e0e6e4882445bc625aaee47f91db469f9fc22` (upstream base `4413a192410fad1f054e9216114087a3e01527a0`). The private CLI adapter retains the existing app protocol; its source and CMake recipe are included under `tools/native-runner`. Binary, library, driver-source and evidence-archive hashes are pinned in `assets/upstream-runtime-build.json`.

Runtime/model source selection now propagates the resolved payload revision through allocation, Send, the shell adapter and metrics. Explicit 1.5.6 runtime identities remain resolvable for restoration and rollback. Six dense models use the new engine; the MoE and vision gates remain unchanged. The UI identifies d57e0e6 and carries no inherited fastest-performance badge. Conservative defaults are row tile 4 and 168 workers on 3120A / 180 on 7120P.

Offline validation covers current/prior source identities, model pairing, shell routing, payload hashes/ELF/runpaths, archive members and the existing host suite. The upstream host reference passed 52 small backend cases, translated-assembly sanitizer tests and synthetic mixed-model state comparisons. These results are separate from native execution. The card was disconnected during integration; native validation was subsequently completed on a 7120P on 13 October 2026. Existing installations, identities, models and card configuration were preserved.

The installed native executable matched its pinned release hash. Both LFM2.5 2.6B Q5_K_M and Llama 3.3 8B Q5_K_M passed generation and three load/reset cycles, with exact agreement between batched, incremental, chunked and reset logits in the fixed-input checks. Stop followed by another response and conversation-history reuse passed with LFM2.5. Automatic allocation completed at 131,072 context tokens for LFM2.5 and 33,792 for Llama, using short prompts; full-length context quality remains untested. Peak measured temperature was 65 C, and all measured runs verified 180-worker affinity.

Three alternating measured runs per version/model used identical weights, prompts, 2,048 context, batch 128 and 64 output tokens after separate warm-ups. Median generation speed was 2.633 to 2.615 tokens/s for LFM2.5 (-0.7%) and 1.168 to 1.182 for Llama (+1.2%), comparing 1.5.6 to 1.5.7. These small differences do not establish a substantial speed improvement. The original model cache was restored and temporary comparison files were removed. Raw native evidence remains outside Git. This validation does not cover the 3120A, other catalog models, visual UI checks, or deliberate thermal/heartbeat-loss fault injection.

## 1.5.6: loading models after standalone setup

Standalone bootstrap receipts describe a runtime without a bundled model. Cache cleanup, model transfer and chat readiness now treat the legacy `model_sha256` field as optional. A legacy generic model file without a pinned identity must still be verified before removal. The installed/downloaded model and shared native runtime are reusable after this correction.

The existing standalone host checks include a focused model load/cache/readiness regression using the actual bootstrap receipt shape, without a model hash. Network and transfer calls in that check are fixtures; native validation is recorded separately. App and installer version markers are both 1.5.6. Native binaries and model files are unchanged.

The subsequent native chat check exposed CRLF line endings from Windows PowerShell here-strings reaching the card's Linux shell. SSH commands now normalize CRLF to LF at the transport boundary; the existing transport suite checks this on Windows before its Linux-only process tests.

The interrupted 1.5.5 installation was repaired in place and completed Probe, Health and Load using its existing identity, accepted shared runtime and downloaded LFM2.5 Q5_K_M model. A real response then completed on the 7120P with automatic allocation (131,072 context, batch 128, 180 workers): 39 generated tokens at 2.679 tokens/s, peak temperature 60 C. This is one model/chat smoke check, not a new full hardware acceptance or clean-PC installation run. No card reset, service or network reconfiguration was performed for this repair.

## 1.5.5: simpler Windows permissions and installer contents

The original 1.5.4 error was a noncanonical inherited ACL. Its rollback then replayed an old security descriptor including SYSTEM ownership and failed because Windows did not allow assigning that owner. Private-file permissions now use a fresh restricted DACL; directory permissions and backup/restore leave existing owners unchanged. Old journals remain readable, but only their access rules are restored. A partially completed rollback skips copying files whose bytes already match their backups.

Four focused cases were added to the existing SSH setup suite using actual Windows permissions on disposable files: a noncanonical ACL, replacement with a restricted canonical DACL, ignoring a saved SYSTEM owner, and preserving directory ownership. The existing host suite remains the development check. These tests do not configure hardware.

The Windows installer excludes developer test suites, build tools, CI and repository metadata; those stay in the source ZIP. Normal runtime setup no longer measures vendor/integration throughput. Native compatibility checks, file hashes, backups and hardware temperature/memory monitoring remain. Native binaries/model files are unchanged from 1.5.4.

## 1.5.4: optional MPSS stack service and shared inference engine

The reported full MPSS installation has a stopped `micRAS` telemetry service and no service named `mpss`. Setup had treated that optional name as mandatory and stopped before changing the adapter, SSH identity or boot image. Startup now permits an absent stack service, waits for required telemetry, handles pending starts, and reports missing/failed telemetry. Only exact service names are queried; Windows Firewall is never selected.

Windows PowerShell 5.1 host validation covers 12 service regression checks (absent/running/stopped/pending stack, missing telemetry, timeout and denied start), 11 first-run checks using the actual repaired service function against service/MPSS/network doubles, installer UAC handoff, setup transactions and the existing application regression suite. The shared runtime checks exercise both hardware topologies with contiguous/interleaved CPU numbering, all worker counts, invalid placement, exact engine routing, missing/wrong receipts, ELF and library identity, and full payload hashes. These are host tests, not hardware acceptance.

All six supported chat models require `shared-multi-quant-v1`; old runtimes cannot silently satisfy that requirement. TinyDolphin retains ChatML, verified against its hash-pinned local GGUF (EOS 32000). The 7120P package uses the upstream r4 export; 3120A uses its latest r3 candidate. [Build evidence and remaining native qualification](SHARED-RUNTIME.md) are separate from app acceptance. Old installation directories and native release ZIPs remain preserved. No card reset, boot, service start or host configuration change was used to test this repair.

## 1.5.3: Windows installer launch repair

The reported 1.5.2 failure immediately after accepting UAC was reproduced with the installer entry point. An array expression joined a parameter name and value into one argument (`-Model lfm2.5-2.6b-q5_k_m`), causing the elevated PowerShell process to reject its arguments before setup or error logging began. The corrected expression passes two separate arguments, including for paths containing spaces.

A separate read-only preflight found that the adapter expression matched `MIC` inside `Microsoft`. Hidden Wi-Fi Direct and kernel debugging adapters then caused a false ambiguous-device failure. Matching now requires a separate MIC word or a Xeon Phi driver name. Regression cases cover the observed Intel driver name, Microsoft virtual adapters, legacy MIC names and explicitly selected non-Phi interfaces.

Windows PowerShell 5.1 host validation passed on October 12, 2026: 59 scripts parsed, 42 setup checks, 15 installer entry checks, and all prior first-run, identity, chat, model and runtime tests. The entry tests run the real parent/child scripts from a directory containing spaces, simulate elevation, preserve the underlying preflight error in both console and saved diagnostics, and prove logging does not create a conflicting installation destination. Plan remains read-only.

The corrected read-only preflight on the reported PC selected the single Phi adapter and retained its existing host/card addresses, without planning an address or XML change. This is not a complete hardware installation test. No network, MPSS, SSH identity, runtime or card state was changed. Native archives and model packs are unchanged; 1.5.3 replaces the application/source downloads only.

## 1.5.2: pinned Gaston import and MoE gating

The Windows PowerShell 5.1 host suite passed on October 12, 2026. It includes 84 provenance checks, 38 standalone setup checks, 53 SSH persistence checks, 9 first-run fixtures, and 22 MoE compatibility checks alongside the existing chat, Stop, memory and runtime-pairing regressions. The Bash process harness remains skipped on Windows.

The new checks cover single-model imports, required/unknown IDs, corrupt inputs, duplicate identities, path containment, and conflicts detected before any model copy. The actual Gaston catalog entry remains disabled on unknown, 3120A and 7120P hardware, cannot acquire an engine or prompt, and cannot receive an optimized badge. Editing catalog acceptance flags cannot bypass the architecture gate. MoE allocation rejects both automatic and manual dense-memory estimates.

The complete 5,830,593,408-byte Gaston GGUF was independently hashed against `852cd73ed6ba7d8fcd6ebeae577a75fa7de5f3239c9fe0dce7bf8cc077e20ec3`. The app read the actual file's metadata: 128,000 native context tokens, 32 experts/4 selected, and a 12,288-byte-per-token F16 KV component. Activation memory remains unqualified; no executable memory plan is returned. The original producer tensor audit is preserved byte-for-byte and checked against its receipt. [Full provenance and limitations](LFM2-MOE.md).

Packaging reads back every archive member and checks its size and SHA-256. The separate Gaston pack includes the audited weights, sanitized provenance and original tensor audit. Previous 1.5.1 ZIPs remain intact. Native payload sizes, SHA-256 values and runtime IDs are unchanged.

No card, installed application, MPSS setting or SSH trust was changed. No fresh native MoE test or fresh-PC hardware installation is claimed. Gaston chat remains unavailable until a compatible runtime is separately built and qualified.

## 1.5.1: independent repository and first-run setup

This release separates the approved 1.5.0 application into an independent repository and adds Windows first-run installation. Native runtime archives and model weights are unchanged. No real card or installed MPSS configuration was changed during this migration: the card was reported offline.

Windows PowerShell 5.1 host checks passed:

- 53 SSH provisioning/persistence checks, including authorization merging, pinned trust, boot transitions and backup rollback.
- 29 standalone setup checks, including network conflict planning, NIC isolation, DHCP/address rollback, source copying/resume, corrupted assets, real disposable key generation/reuse, connection containment and model pack verification.
- 9 complete first-run checks against a disposable MPSS fixture with no initial image, key, saved connection or runtime acceptance. Services, network commands, micctrl and SSH were mocked; the function generated a bootstrap image, provisioned boot files and required the expected boot proof before recording host verification.
- Application host regressions for hardware profiles, memory/context allocation, chat navigation, rename/delete, Stop/resume, statistics, context ring, model/runtime pairing, exact runtime restore identity, watchdog extraction, failed native-install transactions and rollback.
- 13 state-file checks. Windows concurrent replacement exposed a race in the inherited helper; 1.5.1 serializes writers per path across processes and retries brief read/open contention. This is a host state-file fix, not a change to native inference.

The Windows suite explicitly skips the Bash process harness. Python/Bash orchestration fixtures remain available to developers but were not rerun as part of this Windows-only migration. `tools/Test-Host.ps1` needs no Phi card or native payloads. Permission tests create and remove disposable local SSH keys; they may require execution outside a restricted agent sandbox.

Release packaging verifies pinned runtime/model sizes and SHA-256 hashes, then reads every ZIP member back and compares it with its source. Source and release inputs contain no saved chats, private keys, active card selection, developer connection file or copied Intel/Windows installation.

The 7120P runtime's previous native validation is inherited from the approved release. The 3120A archive retains its pinned identity and has not received a new hardware qualification here. Fresh-PC MPSS initialization, real networking, reboot, native runtime tests and first-model load still require a live-card installation test. Setup performs those checks on the user's hardware and will not mark installation complete when they fail.

The Windows replacement retry uses the documented behavior of [ReplaceFile](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilea), including error 1175 retaining both original filenames.

