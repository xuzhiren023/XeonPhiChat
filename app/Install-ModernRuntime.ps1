#Requires -Version 5.1
# Installer fix 1.4.3.2; application and native payload versions are unchanged.
[CmdletBinding()]
param([string]$RuntimePackageDir='', [switch]$Rollback)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/ChatCore.ps1')
$transcript=$false; $job=''; $child=$null
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Run this script on the Windows MPSS laptop.' }
    foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction Stop)) {
        if ($process.CommandLine -and $process.CommandLine -match '(?i)(Start-PhiChat|Invoke-PhiJob)\.ps1' -and
            $process.CommandLine.IndexOf($PSScriptRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'Close Phi Chat and wait for its worker before changing the runtime.' }
    }
    $connection=Read-PhiConnection $PSScriptRoot
    $job=Join-Path $connection.data_dir ('jobs/modern-runtime-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
    $null=New-Item -ItemType Directory -Path $job -Force
    $null=Start-Transcript -LiteralPath (Join-Path $job 'installer-console.txt'); $transcript=$true
    Write-Host "Runtime operation evidence: $job"
    if ($RuntimePackageDir -and !$Rollback) {
        $RuntimePackageDir=(Resolve-Path -LiteralPath $RuntimePackageDir).Path
        $pin=Read-JsonFile (Join-Path $PSScriptRoot 'config/modern-runtime.json')
        . (Join-Path $PSScriptRoot 'lib/ModernRuntime.ps1')
        # Cache both pinned SKU payloads for future card swaps and reboot restore.
        foreach ($payload in $pin.payloads) {
            $incoming=Join-Path $RuntimePackageDir $payload.file
            Assert-ModernPayload $incoming $payload
            $store=Join-Path $connection.data_dir ('modern-runtime/payload-'+$payload.sha256)
            $null=New-Item -ItemType Directory -Path $store -Force
            Copy-Item -LiteralPath $incoming -Destination (Join-Path $store $payload.file) -Force
        }
    }
    $action=if ($Rollback) { 'RollbackModern' } else { 'InstallModern' }
    Write-JsonFile (Join-Path $job 'request.json') ([pscustomobject]@{action=$action;batch=128;owner_pid=$PID;runtime_package_dir=$RuntimePackageDir})
    Write-Host 'Preparing runtime. Progress will appear below.'
    $arguments=Join-NativeArguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'Invoke-PhiJob.ps1'),'-JobDir',$job)
    # Own the process handle through completion; do not depend on the process
    # object returned by Start-Process to retain an exit code on Windows.
    $child=New-Object Diagnostics.Process
    $child.StartInfo.FileName=(Get-Command powershell.exe).Source
    $child.StartInfo.Arguments=$arguments
    $child.StartInfo.UseShellExecute=$false
    $child.StartInfo.CreateNoWindow=$false
    if (!$child.Start()) { throw 'Runtime worker did not start.' }
    $null=$child.Handle
    $last=''; $next=[DateTime]::UtcNow
    while (!$child.WaitForExit(300)) {
        $statusPath=Join-Path $job 'status.json'
        if (Test-Path -LiteralPath $statusPath) {
            $status=Read-JsonFile $statusPath
            if ($status.message -cne $last -or [DateTime]::UtcNow -ge $next) {
                Write-Host ((Get-Date -Format 'HH:mm:ss')+' '+$status.message)
                $last=$status.message; $next=[DateTime]::UtcNow.AddSeconds(15)
            }
        }
    }
    $child.WaitForExit(); $code=$child.ExitCode
    Write-JsonFile (Join-Path $job 'installer-worker-exit.json') ([pscustomobject]@{exit_code=$code;installer_version='1.4.3.2';observed_utc=[DateTime]::UtcNow.ToString('o')})
    if ($null -eq $code) { throw 'Worker exit code is unavailable. Do not rerun native tests yet; retain status.json and modern-selection.json for completion recovery.' }
    $status=Read-JsonFile (Join-Path $job 'status.json')
    if ($code -ne 0 -or $status.state -cne 'done') { throw "Runtime activation failed (exit=$code): $($status.message)" }
    if (!$Rollback) {
        $selection=Read-JsonFile (Join-Path $job 'modern-selection.json')
        if (!$selection.enabled -or $selection.validation -cne 'native-kernels-dispatch-and-cli-startup') { throw 'Missing successful runtime activation receipt.' }
    }
    Write-Host ('PASS: '+$status.message)
} catch {
    Write-Host ('FAIL: '+$_.Exception.Message) -ForegroundColor Red
    if ($job) {
        Write-Host "Evidence: $job"
        if (Test-Path -LiteralPath (Join-Path $job 'failure.txt')) { Write-Host ([IO.File]::ReadAllText((Join-Path $job 'failure.txt'))) }
        Write-Host 'Keep failure.txt, status.json, process-*.exit.json, process-*.stderr.txt and native-validation.txt together.'
    }
    exit 1
} finally {
    if ($child) { $child.Dispose() }
    if ($transcript) { $null=Stop-Transcript }
}
