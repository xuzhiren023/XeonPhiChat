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
    if ($found.sha256 -cne $payload.sha256 -or $found.modern_source_commit -cne $pin.modern_source_commit) { throw 'Saved runtime ID resolved to a different archive or source.' }
    $wrong=@($pin.payloads | Where-Object { $_.profile -cne $payload.profile })[0]
    $failed=$false
    try { $null=Get-ModernPayload $health '1.4.2' $wrong.runtime_id } catch { $failed=$true }
    if (!$failed) { throw 'Runtime from a different card profile was accepted.' }
    Write-Output ('PASS: exact runtime ID/SHA for '+$payload.profile+'; wrong-profile runtime rejected.')
}
foreach ($saved in (Read-JsonFile (Join-Path $AppRoot 'config/modern-runtime-1.5.6-shared.json')).payloads) {
    $health=[pscustomobject]@{profile=[pscustomobject]@{profile_id=$saved.profile}}
    $found=Get-ModernPayload $health '1.4.2' $saved.runtime_id
    if ($found.sha256 -cne $saved.sha256 -or $found.modern_source_commit -cne '6783b11fb0889d68d0046176b4cc92ceee1961b0') { throw '1.5.6 runtime restore pin changed.' }
}
Write-Output 'PASS: previous 1.5.6 runtime IDs, hashes and source pins remain available for restore'
$candidatePin=Read-JsonFile (Join-Path $AppRoot 'config/modern-runtime-numerics-r3.json')
$candidate=$candidatePin.payloads[0]
$candidateHealth=[pscustomobject]@{profile=[pscustomobject]@{profile_id='xeon-phi-7120p'}}
$resolved=Get-ModernPayload $candidateHealth '1.4.2' $candidate.runtime_id
if ($resolved.sha256 -cne $candidate.sha256 -or $resolved.main_sha256 -cne 'e3366b50052818a7cc223f57b7b69f55316e5cd93e3ca9b67b413a849b235d54' -or
    $resolved.modern_source_commit -cne '61e97998bf49c2d425563920b7e83e52b5ae57a6') { throw 'Numerics candidate pin mismatch.' }
foreach ($profile in @('xeon-phi-3120a','xeon-phi-5110p')) {
    $rejected=$false
    try { $null=Get-ModernPayload ([pscustomobject]@{profile=[pscustomobject]@{profile_id=$profile}}) '1.4.2' $candidate.runtime_id } catch { $rejected=$true }
    if (!$rejected) { throw '7120P qualification was inherited by another card.' }
}
if ((Get-ModernPayload $candidateHealth).runtime_id -cne $candidate.runtime_id) { throw '7120P default does not select the multimodal runtime.' }
Write-Output 'PASS: optional numerics runtime resolves by exact 7120P ID/hash; other cards rejected; default and rollback pins preserved.'
$script:health=$candidateHealth
$candidateState=[pscustomobject]@{modern_runtime_version='1.4.2';modern_runtime_id=$candidate.runtime_id;modern_source_commit=$candidatePin.modern_source_commit}
foreach($model in Get-ChildItem (Join-Path $AppRoot 'config/models') -Filter '*.yaml' | ForEach-Object {Read-JsonFile $_.FullName}) {
    if ($model.architecture -cin @('llama','lfm2') -and $model.required_source_commit -ceq 'd57e0e6e4882445bc625aaee47f91db469f9fc22') {
        if (!(Test-ModernModelSource $model $candidateState)) { throw 'Qualified existing model revision rejected.' }
    }
}
$unknown=[pscustomobject]@{required_source_commit=('0'*40)}
if (Test-ModernModelSource $unknown $candidateState) { throw 'Unlisted model revision accepted.' }
$candidateState.modern_source_commit='6783b11fb0889d68d0046176b4cc92ceee1961b0'
if (Test-ModernModelSource ([pscustomobject]@{required_source_commit='d57e0e6e4882445bc625aaee47f91db469f9fc22'}) $candidateState) { throw 'Payload/source mismatch accepted.' }
Write-Output 'PASS: pinned model-source compatibility; unknown revisions and inconsistent runtime state rejected.'
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
