#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('State','Trace','Benchmark','Lifecycle','Context','All')][string]$Phase='State',[ValidateRange(3,10)][int]$Repetitions=5,[ValidateSet('lfm2.5-2.6b-q5_k_m','llama-3.3-8b-abliterated-q2_k','llama-3.3-8b-abliterated-q5_k_m')][string]$Model='lfm2.5-2.6b-q5_k_m')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/ChatCore.ps1')
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Run on the configured Windows MPSS laptop.' }
foreach ($process in @(Get-CimInstance Win32_Process)) {
    if ($process.CommandLine -and $process.CommandLine -match '(?i)(Start-PhiChat|Invoke-PhiJob)\.ps1' -and $process.CommandLine.IndexOf($PSScriptRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'Close PhiChat and wait for its current job before acceptance tests.' }
}
$cfg=Read-PhiConnection $PSScriptRoot
$evidence=Join-Path $cfg.data_dir ('acceptance/modern-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
$null=New-Item -ItemType Directory -Path $evidence -Force
$script:testIndex=0
function Run-TestJob([string]$Name,$Request,[switch]$ExpectPromptReject) {
    $script:testIndex++
    $path=Join-Path $evidence (('{0:D3}-' -f $script:testIndex)+$Name)
    $null=New-Item -ItemType Directory -Path $path
    $Request.owner_pid=$PID; $Request.batch=32
    Write-JsonFile (Join-Path $path 'request.json') $Request
    & (Get-Command powershell.exe).Source -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-PhiJob.ps1') -JobDir $path | Out-Host
    if ($ExpectPromptReject) {
        $status=Read-JsonFile (Join-Path $path 'status.json')
        if ($LASTEXITCODE -eq 0 -or !(Test-RecoverableChatFailure $status)) { throw "Expected a recoverable context rejection. Preserve $path" }
    } elseif ($LASTEXITCODE -ne 0) { throw "Test failed. Preserve $path" }
    Write-Host "Completed $Name; evidence: $path"
    return $path
}
$healthJob=Run-TestJob 'health' @{action='Health'}
$health=Read-JsonFile (Join-Path $healthJob 'hardware.json')
$lfm=$Model
function Load-TestModel([string]$Id) {
    $j=Run-TestJob ('load-'+$Id) @{action='Load';model=$Id;connected_serial=$health.serial}
    return Read-JsonFile (Join-Path $j 'ready.json')
}
$ready=Load-TestModel $lfm
function Run-Lfm([string]$Mode,[string]$Label,[int]$Tokens=128) {
    return Run-TestJob $Label @{action='Chat';model=$lfm;connected_serial=$health.serial;ready=$ready;context_tokens=2048;output_tokens=$Tokens;messages=@(@{role='user';content='Compute 7 plus 5.'});modern_test_mode=$Mode}
}
if ($Phase -in @('State','All')) { $null=Run-Lfm 'validate' 'state-three-load-reset-cycles' }
if ($Phase -in @('Trace','All')) { $null=Run-Lfm 'trace' 'trace-not-performance' }
if ($Phase -in @('Benchmark','All')) {
    # Warm both paths first; alternate order to reduce thermal/order bias.
    $null=Run-Lfm 'baseline' 'warm-baseline' 64;$null=Run-Lfm 'optimized' 'warm-optimized' 64
    for ($i=0;$i -lt $Repetitions;$i++) {
        $order=if ($i%2) { @('optimized','baseline') } else { @('baseline','optimized') }
        foreach ($mode in $order) { $null=Run-Lfm $mode ('perf-'+$i+'-'+$mode) 64 }
    }
}
if ($Phase -in @('Context','All')) {
    $null=Run-TestJob 'context-overflow' @{action='Chat';model=$lfm;connected_serial=$health.serial;ready=$ready;context_tokens=2048;output_tokens=128;messages=@(@{role='user';content=('word '*3000)})} -ExpectPromptReject
    $null=Run-Lfm 'optimized' 'reuse-after-context-rejection'
}
if ($Phase -in @('Lifecycle','All')) {
    # Every historical model retains its own engine and template. Downloads and
    # eviction use the existing admission/cache policy, never ad-hoc deletion.
    foreach ($id in @('tinydolphin-q5_k_m')) {
        $legacyReady=Load-TestModel $id
        $j=Run-TestJob ('regression-'+$id) @{action='Chat';model=$id;connected_serial=$health.serial;ready=$legacyReady;context_tokens=2048;output_tokens=32;messages=@(@{role='user';content='What is 2 plus 2?'})}
        $ready=Load-TestModel $lfm
        $j=Run-Lfm 'optimized' ('switch-back-'+$id)
        $answer=[IO.File]::ReadAllText((Join-Path $j 'response.txt'))
        $null=Run-TestJob ('reuse-'+$id) @{action='Chat';model=$lfm;connected_serial=$health.serial;ready=$ready;context_tokens=2048;output_tokens=32;messages=@(@{role='user';content='Compute 7 plus 5.'},@{role='assistant';content=$answer},@{role='user';content='Now add 1 to that result.'})}
    }
}
Write-Host "Evidence saved: $evidence"
Write-Host 'Execution completed. Compare numerical files, inspect replies and memory/temperature logs, and summarize paired timing before claiming hardware acceptance.'
