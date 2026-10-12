# Validation of 1.5.1

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

