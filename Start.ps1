#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    $root=$PSScriptRoot
    if (!(Test-Path -LiteralPath (Join-Path $root 'installation.json'))) {
        $installed=Join-Path $env:LOCALAPPDATA ('Programs/PhiChat/'+[IO.File]::ReadAllText((Join-Path $root 'VERSION')).Trim())
        if (Test-Path -LiteralPath (Join-Path $installed 'installation.json')) { & (Join-Path $installed 'Start.ps1'); exit }
        & (Join-Path $root 'Setup.ps1'); exit
    }
    . (Join-Path $root 'setup/lib/HostSetup.ps1')
    $receipt=Read-Json (Join-Path $root 'installation.json')
    if ($receipt.status -cne 'installed') { throw 'Installation is incomplete. Run Setup.cmd again from the original extracted installer folder, using the same destination.' }
    $settings=Read-Json (Join-Path $root 'data/host/data/settings.yaml')
    $run=Get-PhiSetupRun $root
    $online=$false
    try {
        $state=Get-MicState (Invoke-SetupProcess (Join-Path $settings.mpss_dir 'bin/micctrl.exe') @('-s','mic0') $run)
        $online=($state -ceq 'online')
    } catch {}
    if (!$online) {
        # Boot helper only starts services/boots a ready card; it never resets.
        $p=Start-Process -FilePath (Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe') -Verb RunAs -Wait -PassThru -ArgumentList (Join-NativeArguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'Setup.ps1'),'-Mode','Boot','-Destination',$root,'-OriginalUserSid',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value))
        if ($p.ExitCode -ne 0) { throw 'Card startup did not finish. Review the MPSS status and setup evidence.' }
    }
    & (Join-Path $root 'app/Start-PhiChat.ps1')
} catch {
    Add-Type -AssemblyName PresentationFramework
    [void][Windows.MessageBox]::Show($_.Exception.Message,'Phi Chat')
    exit 1
}
