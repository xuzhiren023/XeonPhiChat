# Setup and recovery

Run `Setup.cmd` from the extracted **Windows** installer. The installer can configure a fresh PC with a supported KNC card and the full MPSS driver package. An INF-only driver lacks the tools and boot filesystem needed to start Linux on the card; install the MPSS package supplied for your hardware first. Phi Chat does not install or replace Intel drivers or firmware.

The installer finds the installed MPSS directory and one healthy KNC PCI device. It chooses only the Phi virtual network adapter. It reuses a valid private /24 in `mic0.xml` when it does not overlap another adapter/route; otherwise it picks an unused /24 under `172.31.0.0/16`. It sets a static address only on that adapter, preserving the LAN, DNS and default gateway. DHCP changes, if needed, are limited to the Phi adapter and recorded for rollback.

Setup creates separate login and server ED25519 keys inside the installed `app/private` folder. Their permissions are restricted to the installing user, SYSTEM and Administrators. The server public key is known before the card boots, so first use does not depend on accepting an unknown network host key. Existing boot authorizations and SSH settings are merged/preserved; explicitly incompatible SSH policy stops setup. The Windows user's global SSH configuration and known_hosts file are not changed. Provisioning a new server identity means older applications with a saved card host-key pin will need that pin updated after verification, or the old boot image restored through rollback.

The console explains and requests permission for the initial card restart, which discards processes/files held only in card RAM. Setup backs up MPSS files and generated images before modifying them. It does not alter clocks, firmware, fan policy or thermal limits. Runtime installation still requires the existing card workload lease, watchdog, native tests, SHA-256 verification and hardware profile match.


## Updating or rerunning setup

Version 1.6.6 fixes the missing `app/Test-ModernRuntime.ps1` error: source installations and the Windows ZIP now use one production file list. Retries tolerate old developer-test entries without requiring or changing those files. Missing or modified production files still produce a clear error.

When a completed installation exists in the normal per-user location or beside the destination, setup installs the new version alongside it and reuses its portable connection, protected SSH identity, host settings and original runtime selection. This application update needs no UAC, host reconfiguration, card restart, connection test or inference. Open the desktop shortcut when ready; the app checks the actual card and runtime normally. Existing models are reused on Load. Completed same-version setup retries only validate the app files and recreate the shortcut.

Previous installations remain intact. Any copied boot recovery records continue to reference their original plans/backups, so keep the previous installation for rollback. Updates do not manufacture a new boot or native-runtime validation result. An interrupted app update resumes from its recorded source; an interrupted first-time setup follows its existing provisioning journal.

## Custom folders

```powershell
.\Setup.ps1 -Destination 'D:\Apps\PhiChat\1.5.7' -MpssDirectory 'C:\Program Files\Intel\MPSS'
.\Setup.ps1 -Mode Plan -MpssDirectory 'C:\Program Files\Intel\MPSS'
.\Setup.ps1 -Mode AddModels -Destination 'D:\Apps\PhiChat\1.5.7' -ModelPackDirectory 'D:\Downloads\PhiChatModels'
```

`Plan` reads hardware/network configuration without writing settings or creating credentials. Depending on local Windows permissions it may need an administrator console. Use `-InterfaceIndex` only to disambiguate Phi virtual adapters; a physical LAN interface is rejected. Automatic installation supports one card (mic0).

## Interrupted setup

Version 1.5.5 replaces problematic inherited Windows permission lists with a fresh private-file DACL. It leaves file ownership alone, including during rollback of older setup journals. This fixes the 1.5.4 failure involving a noncanonical ACL followed by a rejected SYSTEM-owner restore. After you approve setup, it finishes a previous sibling Phi Chat installation's failed permission rollback if all boot-file bytes already match their saved originals. Later operator changes are preserved for explicit recovery. Normal setup no longer runs throughput benchmarks; compatibility checks and boot-file backups remain.

Rerun **the original extracted installer** with the same destination. Saved identities are reused, never silently rotated. Modified application files and unrelated destination folders are preserved with an actionable error. If boot files were generated but verification failed, the next run reuses the recorded transaction. Once host verification succeeds, later retries do not initialize the host again. Runtime selection is accepted only after native validation; model downloads use hash verification and atomic completion.

Early setup errors are saved under `%LOCALAPPDATA%\PhiChat\SetupLogs\<run-id>`, even before an installation exists. The original and elevated windows share that run ID; the original window displays the elevated process's error. The console shows the exact diagnostic folder. `Plan` remains read-only and does not create logs.

Installation evidence is in `data/setup`; protected boot plans/backups are in `data/host`. Runtime jobs and native validation evidence are in `app/data/jobs`. These folders may contain private material and are not source/release inputs.

Version 1.5.4 fixes setup on full Windows MPSS installations that have `micRAS` but no service named `mpss`. The optional stack service is started only if registered; required telemetry is started and awaited. Exact service names are used, so Windows Firewall (`mpssvc`) is never selected. Missing telemetry or a failed service start still stops setup with a specific diagnostic.

If 1.5.3 stopped with "Cannot find any service with service name 'mpss'", extract 1.5.4 into a new folder and run its `Setup.cmd`. That failure occurred before host identity, adapter and boot-image changes. Existing downloads/installations need not be deleted. The earlier UAC argument and Microsoft-adapter fixes remain included.

To restore the previous MPSS boot files and adapter configuration:

```powershell
# Run from the installed app folder (UAC is requested)
.\Setup.ps1 -Mode RollbackHost
```

Rollback refuses changed/damaged backup targets. It does not reset an active card. Restored boot files take effect on its next boot; save current card work first. Generated app data remains available for diagnosis. Rerun the downloaded installer to initialize the card again afterward.

Normal `Start.cmd` boots a ready card and starts MPSS services if needed, requesting UAC for that helper. It never resets an online card. The app's Connect/Restore runtime path restores the exact saved runtime after a card reboot. Chat history belongs to the current card boot and expires when the card goes offline, as in 1.5.0.

Windows feature and network commands follow Microsoft's [OpenSSH client installation documentation](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse) and [New-NetIPAddress documentation](https://learn.microsoft.com/en-us/powershell/module/nettcpip/new-netipaddress). No SSH server feature is installed on Windows.

