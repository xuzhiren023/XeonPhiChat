#Requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$AppRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:root=$AppRoot
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/ModernRuntime.ps1')
$script:cfg=Read-JsonFile (Join-Path $AppRoot 'config/app.yaml')
$pin=Read-JsonFile (Join-Path $AppRoot 'config/modern-runtime.json')
foreach ($payload in $pin.payloads) {
    $health=[pscustomobject]@{profile=[pscustomobject]@{profile_id=$payload.profile}}
    $found=Get-ModernPayload $health '1.4.2' $payload.runtime_id
    if ($found.sha256 -cne $payload.sha256) { throw 'Saved runtime ID resolved to a different archive.' }
    $wrong=@($pin.payloads | Where-Object { $_.profile -cne $payload.profile })[0]
    $failed=$false
    try { $null=Get-ModernPayload $health '1.4.2' $wrong.runtime_id } catch { $failed=$true }
    if (!$failed) { throw 'Runtime from a different card profile was accepted.' }
    Write-Output ('PASS: exact runtime ID/SHA for '+$payload.profile+'; wrong-profile runtime rejected.')
}
$previous=Read-JsonFile (Join-Path $AppRoot 'config/modern-runtime-1.5.3-paired.json')
foreach ($payload in $previous.payloads) {
    $health=[pscustomobject]@{profile=[pscustomobject]@{profile_id=$payload.profile}}
    $found=Get-ModernPayload $health '1.4.2' $payload.runtime_id
    if ($found.sha256 -cne $payload.sha256) { throw 'Previous paired runtime pin was lost.' }
    Write-Output ('PASS: original 1.5.3 runtime still resolves by exact ID for '+$payload.profile)
}

# Exercise first model staging with the standalone, model-free bootstrap shape.
# Only external I/O is replaced; cache cleanup, transfer selection and readiness
# run their application code under StrictMode, as they do in the worker.
& {
    . (Join-Path $AppRoot 'lib/Transport.ps1')
    $state=[pscustomobject]@{schema_version=1;kind='watchdog-bootstrap-only';native_acceptance=$false;source_commit=$script:cfg.source_commit;remote_base='/root/knc-phase3-run-bootstrap';runtime_archive='runtime.tar'}
    $model=Get-ModelProfile $AppRoot 'lfm2.5-2.6b-q5_k_m'
    $script:health=[pscustomobject]@{serial='FIXTURE';profile=(Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml'))}
    $script:cardLockOwned=$true; $script:cardLockToken='fixture'; $script:cleanupMode=$false
    $script:job='fixture'; $script:copiedModel=$false
    function Invoke-Card([string]$Command) {
        if ($Command -ceq 'cat /proc/meminfo') { return "MemTotal: 16000000 kB`nMemFree: 14000000 kB" }
        if ($Command -match 'model\.gguf') { throw 'Fresh runtime attempted to reuse an unpinned bundled model.' }
        return ''
    }
    function Send-CardFiles {}
    function Write-Utf8 {}
    function Write-JsonFile {}
    function Set-JobStatus {}
    function Assert-JobActive {}
    function Update-LoadTemperature {}
    function Require-CardMemory {}
    function Send-ModelFile { $script:copiedModel=$true }
    $remote=Get-CardModel $model $state 'fixture.gguf'
    if (!$script:copiedModel -or $remote -cne ($state.remote_base+'/models/'+$model.id+'.gguf')) { throw 'First model was not staged in its named cache path.' }
    $ready=[pscustomobject]@{model_id=$model.id;model_sha256=$model.sha256;source_commit=$state.source_commit;serial='FIXTURE';remote_base=$state.remote_base;remote_model=$remote}
    Assert-ModelReady $ready $model $state $script:health
    $ready.remote_model=$state.remote_base+'/model.gguf'
    $rejected=$false
    try { Assert-ModelReady $ready $model $state $script:health } catch { $rejected=$_.Exception.Message -like 'Prepared model path*' }
    if (!$rejected) { throw 'Unpinned generic model path was accepted or raised a missing-property error.' }
    $entry=[pscustomobject]@{path=$ready.remote_model;bytes=$model.file_size_bytes;identity=$model.sha256}
    if ((Get-CacheModel $entry @($model) $state).id -cne $model.id) { throw 'Named identity receipt was not used without a baseline model.' }
    $state | Add-Member model_sha256 $model.sha256
    Assert-ModelReady $ready $model $state $script:health
    if ((Get-CacheModel $entry @($model) $state).id -cne $model.id) { throw 'Legacy baseline model lookup regressed.' }
    Write-Output 'PASS: standalone first Load, cache identity and chat readiness work without a baseline model; legacy model pins still work.'
}
