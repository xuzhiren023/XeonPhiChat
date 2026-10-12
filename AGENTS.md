# Phi Chat development

Use Windows PowerShell 5.1 syntax for application/setup scripts and JSON-compatible YAML for profiles. Normal installation and chat must not require Python, WSL, Git or a compiler. Keep Windows/Intel drivers out of the repository.

Run `tools/Test-Host.ps1` for host-only checks. Its network/MPSS fixtures must never touch real hardware. Native acceptance requires a separately available card, exact hardware/runtime identities, guard/heartbeat/Stop checks, thermal and memory checks, and workload ownership. Never represent mocked or inherited results as new native validation. Do not boot/reset or reconfigure a real PC merely to test setup.

Keep binaries, models, generated installations, keys, private trust/configuration, history and native acceptance records out of Git. `assets/payloads` and `dist` are ignored release inputs/outputs. Build releases with `tools/Build-Release.ps1`; it verifies all archive members. No mutable/unpinned runtime download fallback.

Preserve existing user installations and unknown files. Installer changes must be reviewable, resumable and backed up before changing MPSS boot files or the dedicated Phi network adapter. Never alter the physical LAN, default gateway or global SSH trust. Do not weaken SSH restrictions. Model/engine pairing and the performance badge must remain hardware-specific.

