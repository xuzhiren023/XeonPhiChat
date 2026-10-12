#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'setup/lib/HostSetup.ps1')
$checks=0
function Check([bool]$Value,[string]$Message) { $script:checks++; if (!$Value) { throw ('FAIL: '+$Message) } }
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('phi-entry-'+[Guid]::NewGuid().ToString('N'))
New-Directory $scratch
try {
    $fixture=Join-Path $scratch 'extracted download with spaces'; New-Directory $fixture
    Copy-Item -LiteralPath (Join-Path $root 'setup') -Destination (Join-Path $fixture 'setup') -Recurse
    Copy-Item -LiteralPath (Join-Path $root 'Setup.ps1') -Destination (Join-Path $fixture 'Setup.ps1')
    Copy-Item -LiteralPath (Join-Path $root 'VERSION') -Destination (Join-Path $fixture 'VERSION')
    # Replace only fixture entry points. Exercise the real Setup.ps1 parent/child
    # scripts and argument quoting, with no UAC, device query or machine changes.
    Add-Content -LiteralPath (Join-Path $fixture 'setup/lib/HostSetup.ps1') -Value @'
function Test-PhiAdministrator { return ($env:PHI_SETUP_FIXTURE_ADMIN -ceq '1') }
function Get-PhiAssets { param($Root,$AssetsDirectory); return $null }
function Get-PhiHostPlan { param($MpssDirectory,$InterfaceIndex); throw ('Fixture preflight failure: '+$MpssDirectory) }
function Start-Process {
    param($FilePath,$ArgumentList,$Verb,[switch]$Wait,[switch]$PassThru)
    if ($Verb -cne 'RunAs' -or !$Wait -or !$PassThru) { throw 'Unexpected elevation invocation' }
    $env:PHI_SETUP_FIXTURE_ADMIN='1'
    try {
        Microsoft.PowerShell.Management\Start-Process -FilePath $FilePath -ArgumentList ('-NonInteractive '+$ArgumentList) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $env:LOCALAPPDATA 'child.stdout.txt') -RedirectStandardError (Join-Path $env:LOCALAPPDATA 'child.stderr.txt')
    } finally { $env:PHI_SETUP_FIXTURE_ADMIN='0' }
}
'@
    function Run-Entry([string]$Name,[string]$Admin,[string]$Mode='Install') {
        $local=Join-Path $scratch $Name; New-Directory $local
        $target=Join-Path $local 'fresh destination'
        $info=New-Object Diagnostics.ProcessStartInfo
        $info.FileName=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
        $info.Arguments=Join-NativeArguments @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $fixture 'Setup.ps1'),'-Mode',$Mode,'-Destination',$target,'-MpssDirectory','D:\Driver path with spaces\MPSS','-NoLaunch')
        $info.UseShellExecute=$false; $info.CreateNoWindow=$true
        $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true; $info.RedirectStandardInput=$true
        $info.EnvironmentVariables['LOCALAPPDATA']=$local
        $info.EnvironmentVariables['PHI_SETUP_FIXTURE_ADMIN']=$Admin
        $process=New-Object Diagnostics.Process; $process.StartInfo=$info
        try {
            $null=$process.Start(); $process.StandardInput.Close()
            $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
            if (!$process.WaitForExit(45000)) { $process.Kill(); throw 'Setup fixture timed out' }
            $text=$stdout.Result+$stderr.Result
            if (!$text.Contains('Fixture preflight failure')) {
                Write-Output $text
                foreach ($outputName in @('child.stdout.txt','child.stderr.txt')) {
                    $output=Join-Path $local $outputName
                    if (Test-Path -LiteralPath $output) { Get-Content -LiteralPath $output }
                }
            }
            Check ($process.ExitCode -eq 1 -and $text.Contains('Fixture preflight failure: D:\Driver path with spaces\MPSS')) ($Name+': original preflight error reaches caller with quoted path intact')
            Check (!(Test-Path -LiteralPath $target)) ($Name+': diagnostics do not create an installation destination')
            $logs=Join-Path $local 'PhiChat/SetupLogs'
            if ($Mode -ceq 'Plan') {
                Check (!(Test-Path -LiteralPath $logs)) 'Plan does not write diagnostics or other state'
            } else {
                $runs=@(Get-ChildItem -LiteralPath $logs -Directory)
                $files=@(Get-ChildItem -LiteralPath $logs -Recurse -Filter 'error-*.json')
                $expected=if ($Admin -ceq '1') { 1 } else { 2 }
                Check ($runs.Count -eq 1 -and $files.Count -eq $expected) ($Name+': parent and child share one diagnostic run and preserve individual errors')
                foreach ($file in $files) {
                    $errorRecord=Read-Json $file.FullName
                    Check ($errorRecord.message.Contains('Fixture preflight failure') -and $errorRecord.position -and $errorRecord.script_stack) ($Name+': saved error contains the cause and PowerShell source location')
                }
                Check ($text.Contains($runs[0].FullName)) ($Name+': console points to an existing diagnostic folder')
            }
        } finally { $process.Dispose() }
    }
    Run-Entry 'uac handoff' '0'
    Run-Entry 'already elevated' '1'
    Run-Entry 'read-only plan' '1' 'Plan'
    $failed=$false; try { New-PhiSetupDiagnostics '../escape' | Out-Null } catch { $failed=$true }
    Check $failed 'diagnostic ID cannot supply a path'
    Write-Output ('PASS: '+$checks+' installer entry checks; UAC simulated, no card or host configuration touched.')
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^phi-entry-[a-f0-9]{32}$') { throw 'Unsafe entry test cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
