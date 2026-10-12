# Regression for the operator's real screenshot and the RAM-backed model budget.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/ChatCore.ps1')
$model=Get-ModelProfile $root 'lfm2.5-2.6b-q5_k_m'
$profile=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-3120a.yaml')
$need=Get-MemoryRequirement $model $profile -IncludeModelFile
if ($need.required_mib -ne 3642 -or $need.model_file_mib -ne 1850 -or $need.reserve_mib -ne 256) { throw 'Incorrect file/runtime/reserve accounting.' }
$memory=Read-MemorySnapshot "MemTotal: 5879692 kB`nMemFree: 4404576 kB`n"
if ($memory.available_kib -lt $need.required_mib*1024) { throw 'Operator screenshot is incorrectly rejected.' }
Write-Output 'PASS: 4,404,576 KiB free admits the actual LFM file + runtime + reserve (3,642 MiB)'
$after=Get-MemoryRequirement $model $profile
if ($after.model_file_mib -ne 0 -or $after.required_mib -ne 1792) { throw 'Already-resident model copy was counted again.' }
Write-Output 'PASS: already-resident model copy is not charged twice'
# Check the real transport path, without SSH or a card.
. (Join-Path $root 'lib/Transport.ps1')
$script:job=Join-Path ([IO.Path]::GetTempPath()) ('phi-memory-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $script:job
$script:health=[pscustomobject]@{profile=$profile}
$script:fixtureMemory="MemTotal: 5879692 kB`nMemFree: 4404576 kB`n"
function Invoke-Card { param([string]$Command); if ($Command -cne 'cat /proc/meminfo') { throw 'Unexpected command' }; return $script:fixtureMemory }
function Set-JobStatus { param([string]$Message); }
try {
    Require-CardMemory $model -IncludeModelFile
    $record=Get-Content -LiteralPath (Join-Path $script:job 'memory-admission.jsonl') -Raw | ConvertFrom-Json
    if ($record.requirement.required_mib -ne 3642) { throw 'Admission evidence not saved' }
    Write-Output 'PASS: transport accepts the screenshot and records allocation components'
    $script:fixtureMemory="MemTotal: 5879692 kB`nMemFree: 3000000 kB`n"
    $message=''
    try { Require-CardMemory $model -IncludeModelFile } catch { $message=$_.Exception.Message }
    if ($message -notmatch 'Short by' -or $message -notmatch 'runtime 1536' -or $message -notmatch 'reserve 256') { throw 'Insufficient-memory error lost its breakdown.' }
    Write-Output 'PASS: real shortage remains blocked with required/available/shortfall details'
} finally { Remove-Item -LiteralPath $script:job -Recurse -Force }
