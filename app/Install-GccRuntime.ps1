#Requires -Version 5.1
[CmdletBinding()]
param([string]$RuntimePackageDir='', [switch]$Rollback)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/ChatCore.ps1')
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Run this script on the Windows MPSS laptop.' }
foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction Stop)) {
    if ($process.CommandLine -and $process.CommandLine -match '(?i)(Start-PhiChat|Invoke-PhiJob)\.ps1' -and
        $process.CommandLine.IndexOf($PSScriptRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'Close Phi Chat and wait for its worker to finish before changing the runtime.' }
}
$connection=Read-PhiConnection $PSScriptRoot
if ($RuntimePackageDir) { $RuntimePackageDir=(Resolve-Path -LiteralPath $RuntimePackageDir).Path }
$job=Join-Path $connection.data_dir ('jobs/gcc-runtime-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$null=New-Item -ItemType Directory -Path $job -Force
$action=if ($Rollback) { 'RollbackKernel' } else { 'InstallKernel' }
Write-JsonFile (Join-Path $job 'request.json') ([pscustomobject]@{action=$action;batch=128;owner_pid=$PID;runtime_package_dir=$RuntimePackageDir})
Write-Host "Runtime operation evidence: $job"
Write-Host 'Selecting the detected card variant and validating native execution. Ctrl+C stops the operation; the native guard expires if the connection is lost.'
& (Get-Command powershell.exe).Source -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-PhiJob.ps1') -JobDir $job
$code=$LASTEXITCODE
$status=Join-Path $job 'status.json'
if (Test-Path -LiteralPath $status) { Write-Host (Read-JsonFile $status).message }
if ($code -ne 0) { throw "Runtime operation failed; the previous runtime selection remains available. Evidence: $job" }
Write-Host 'Open Phi Chat, Connect, select a supported model, then Load model.'
