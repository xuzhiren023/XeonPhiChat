# Validation

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

