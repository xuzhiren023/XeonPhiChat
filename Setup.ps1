#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install','Plan','AddModels','RollbackHost','Boot')][string]$Mode='Install',
    [string]$Destination='', [string]$MpssDirectory='', [int]$InterfaceIndex=0,
    [string]$AssetsDirectory='', [string]$ModelPackDirectory='',
    [string[]]$ModelIds=@(),
    [string]$Model='lfm2.5-2.6b-q5_k_m', [string]$OriginalUserSid='', [switch]$NoLaunch,
    [ValidatePattern('^$|^[a-f0-9]{32}$')][string]$DiagnosticId=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$diagnostics=''

function Confirm-PhiAction([string]$Message) {
    Write-Host $Message
    if ((Read-Host 'Type YES to continue') -cne 'YES') { throw 'Setup cancelled. No further changes made.' }
}
function Invoke-PhiElevation {
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-Mode',$Mode,
        '-Destination',$Destination,'-OriginalUserSid',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value,
        '-DiagnosticId',(Split-Path $diagnostics -Leaf))
    foreach ($entry in @(@('MpssDirectory',$MpssDirectory),@('AssetsDirectory',$AssetsDirectory),@('ModelPackDirectory',$ModelPackDirectory),@('Model',$Model))) {
        if ($entry[1]) { $arguments+=@(('-'+$entry[0]),$entry[1]) }
    }
    if ($InterfaceIndex) { $arguments+=@('-InterfaceIndex',[string]$InterfaceIndex) }
    if ($NoLaunch) { $arguments+='-NoLaunch' }
    # Interactive installer: the user needs to review the elevated console.
    $p=Start-Process -FilePath (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -ArgumentList (Join-NativeArguments $arguments) -Verb RunAs -Wait -PassThru
    try {
        if ($p.ExitCode -ne 0) { throw ('Elevated setup stopped: '+(Get-PhiElevatedFailure $diagnostics $p.Id)) }
    } finally { $p.Dispose() }
}
try {
    . (Join-Path $PSScriptRoot 'setup/lib/HostSetup.ps1')
    . (Join-Path $PSScriptRoot 'setup/lib/AppUpdate.ps1')
    Assert-Windows
    if ($Mode -cne 'Plan') { $diagnostics=New-PhiSetupDiagnostics $DiagnosticId }
    if ($ModelIds.Count -and $Mode -cne 'AddModels') { throw '-ModelIds is supported only with -Mode AddModels.' }
    if (!$Destination) {
        $Destination=if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'installation.json')) { $PSScriptRoot } else { Join-Path $env:LOCALAPPDATA ('Programs/PhiChat/'+(Get-PhiVersion $PSScriptRoot)) }
    }
    $Destination=Resolve-Absolute $Destination
    if ($Mode -ceq 'AddModels') {
        if (!(Test-Path -LiteralPath (Join-Path $Destination 'installation.json'))) { throw 'Run Setup.cmd to install Phi Chat first.' }
        if (!$ModelPackDirectory) { $ModelPackDirectory=(Read-Host 'Folder containing the extracted optimized models pack').Trim('"') }
        $import=Import-PhiOptimizedModels $PSScriptRoot $Destination $ModelPackDirectory $ModelIds
        Write-Host ($import.count.ToString()+' pinned model(s) imported and verified. Runtime compatibility is checked separately by the app.')
        if ($import.blocked_model_ids.Count) { Write-Host ('Stored for later use; a validated KNC MoE runtime is still required: '+($import.blocked_model_ids -join ', ')) }
        exit 0
    }
    if ($Mode -ceq 'Plan') { Get-PhiHostPlan $MpssDirectory $InterfaceIndex | ConvertTo-Json -Depth 8; exit 0 }
    if ($OriginalUserSid -and [Security.Principal.WindowsIdentity]::GetCurrent().User.Value -cne $OriginalUserSid) { throw 'Use the same Windows account for UAC elevation so generated SSH keys remain owned by the app user.' }
    # A completed installation already has its host identity. App updates and
    # same-version retries finish locally, before UAC or any hardware calls.
    if ($Mode -ceq 'Install' -and (Invoke-PhiApplicationUpdate $PSScriptRoot $Destination $AssetsDirectory $ModelPackDirectory)) { exit 0 }
    if (!(Test-PhiAdministrator)) {
        Write-Host 'Windows will request permission to configure the Phi virtual adapter and MPSS boot files.'
        Invoke-PhiElevation
        if ($Mode -ceq 'Install' -and !$NoLaunch) { & (Join-Path $Destination 'Start.ps1') }
        exit 0
    }
    if ($Mode -in @('RollbackHost','Boot')) {
        $state=Join-Path $Destination 'data/host'
        $run=Get-PhiSetupRun $Destination
        if ($Mode -ceq 'RollbackHost') {
            $saved=Read-Json (Join-Path $state 'pending.json')
            $plan=Read-SshPersistencePlan $saved.plan_directory
            Confirm-PhiAction 'Restore the saved MPSS boot files and Phi adapter settings from before this installation? The card is not reset automatically; restored files take effect on its next boot.'
            $journal=Read-Json (Join-Path $saved.plan_directory 'journal.json')
            Assert-IdentityInputs $journal.after
            Restore-IdentityTargets $journal $saved.plan_directory
            Undo-PhiNetwork (Read-Json $saved.network_journal)
            foreach ($name in @('verified.json','pending.json')) { $p=Join-Path $state $name; if (Test-Path -LiteralPath $p) { Move-Item -LiteralPath $p -Destination ($p+'.rolled-back-'+[Guid]::NewGuid().ToString('N')) } }
            Write-Host 'Previous boot files and adapter settings restored. Reboot the card when its current work is saved.'
        } else {
            # Boot needs the installed MPSS location, not an old provisioning
            # journal. Early application-only updates have no such journal.
            $settings=Read-Json (Join-Path $state 'data/settings.yaml')
            Start-PhiServices $settings.mpss_dir $run
            $micctrl=Join-Path $settings.mpss_dir 'bin/micctrl.exe'
            Ensure-Online { Invoke-SetupProcess $micctrl @('-s','mic0') $run } { $null=Invoke-SetupProcess $micctrl @('-b','mic0') $run } { Start-Sleep -Seconds 2 }
        }
        exit 0
    }
    $null=Get-PhiAssets $PSScriptRoot $AssetsDirectory
    $hostPlan=Get-PhiHostPlan $MpssDirectory $InterfaceIndex
    Write-Host ("Phi Chat {0}`nInstall folder: {1}`nMPSS: {2}`nDedicated Phi adapter: {3} (index {4})`nHost/card addresses: {5} / {6}" -f (Get-PhiVersion $PSScriptRoot),$Destination,$hostPlan.mpss,$hostPlan.interface_description,$hostPlan.interface_index,$hostPlan.host_address,$hostPlan.card_address)
    $verified=Join-Path $Destination 'data/host/verified.json'
    if (!(Test-Path -LiteralPath $verified)) {
        Confirm-PhiAction 'Setup will install the Windows SSH client if needed, set a static address on the Phi adapter, create SSH keys, back up and rebuild the MPSS boot image, then restart mic0. Restarting discards work stored only in card RAM. The card receives a new SSH host identity; other tools with saved trust pins may need their pins updated. Close other Phi applications and save card work first. Setup then validates the native runtime and downloads the first model (about 2 GB by default).'
    } else { Confirm-PhiAction 'Resume this installation using its saved identity and card configuration, validate/restore its runtime, and prepare the selected model?' }
    Repair-PhiInterruptedPermissions $Destination $hostPlan.mpss
    $receipt=Copy-PhiApplication $PSScriptRoot $Destination
    Install-PhiAssets $PSScriptRoot $AssetsDirectory $Destination
    $run=Get-PhiSetupRun $Destination
    $pendingPath=Join-Path $Destination 'data/host/pending.json'
    if (!(Test-Path -LiteralPath $verified)) {
        if (Test-Path -LiteralPath $pendingPath) {
            $pending=Read-Json $pendingPath; $plan=Read-SshPersistencePlan $pending.plan_directory
            $journal=Read-Json (Join-Path $pending.plan_directory 'journal.json'); Assert-IdentityInputs $journal.after
            Start-PhiServices $plan.mpss $run
            $micctrl=Join-Path $plan.mpss 'bin/micctrl.exe'
            $initial=Get-MicState (Invoke-SetupProcess $micctrl @('-s','mic0') $run)
            Restart-MicIdentity $initial { Invoke-SetupProcess $micctrl @('-s','mic0') $run } { $null=Invoke-SetupProcess $micctrl @('-r','mic0') $run } { $null=Invoke-SetupProcess $micctrl @('-b','mic0') $run } { Start-Sleep -Seconds 2 }
            $boot=Test-PhiBootIdentity $Destination $plan $run
            Write-PhiConnection $Destination $plan.mpss $plan.address
            Save-Json $verified ([pscustomobject]@{schema_version=1;boot_id=$boot;plan_directory=$pending.plan_directory;verified_utc=[DateTime]::UtcNow.ToString('o')})
        } else { $null=Initialize-PhiHost $Destination $hostPlan $run }
    } else {
        $saved=Read-Json $verified; $plan=Read-SshPersistencePlan $saved.plan_directory
        $null=Test-PhiBootIdentity $Destination $plan $run
    }
    if ($ModelPackDirectory) { $null=Import-PhiOptimizedModels $PSScriptRoot $Destination $ModelPackDirectory }
    $probe=Invoke-PhiSetupJob $Destination 'Probe'
    $selection=Join-Path $Destination ('app/data/modern-runtime/active-'+$probe.result.serial+'.json')
    if (!(Test-Path -LiteralPath $selection)) { $null=Invoke-PhiSetupJob $Destination 'InstallModern' }
    $null=Invoke-PhiSetupJob $Destination 'Health'
    $null=Invoke-PhiSetupJob $Destination 'Load' $Model $probe.result.serial
    New-PhiShortcut $Destination
    $receipt.status='installed'; $receipt | Add-Member installed_utc ([DateTime]::UtcNow.ToString('o')) -Force
    Save-Json (Join-Path $Destination 'installation.json') $receipt
    Write-Host 'Phi Chat is installed. Open its desktop shortcut to chat.'
    # An unelevated parent launches the UI after this process exits.
    if (!$OriginalUserSid -and !$NoLaunch) { Write-Host 'Close this administrator console and open Start.cmd normally.' }
    exit 0
} catch {
    Write-Host ('SETUP STOPPED: '+$_.Exception.Message) -ForegroundColor Red
    if ($diagnostics) {
        try { Write-PhiSetupFailure $diagnostics $_; Write-Host ('Setup diagnostics: '+$diagnostics) }
        catch { Write-Host ('Could not save setup diagnostics: '+$_.Exception.Message) }
    }
    if ($Destination -and (Test-Path -LiteralPath (Join-Path $Destination 'data/setup'))) { Write-Host ('Installation evidence: '+(Join-Path $Destination 'data/setup')) }
    Write-Host 'Existing app copies are preserved.'
    if ($Mode -cne 'Plan' -and [Environment]::UserInteractive -and ![Console]::IsInputRedirected) { $null=Read-Host 'Press Enter to close' }
    exit 1
}
