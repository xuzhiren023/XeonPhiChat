#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/Priming.ps1')
function Check([bool]$Value,[string]$Message) {if (!$Value) {throw ('FAIL: '+$Message)};Write-Output ('PASS: '+$Message)}
$script:root=$AppRoot
$profile=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
$pin=(Read-JsonFile (Join-Path $AppRoot 'config/priming-runtime.json')).payloads[0]
Check ($pin.runtime_id -ceq 'knc-decode3-ecf5e24ef6c0a4f3' -and $pin.bytes -gt 14592000) 'decode3 selects the recorded native-tested payload'
foreach ($id in @('lfm2.5-2.6b-q5_k_m','lfm2.5-vl-3b-q5_k_m','llama-3.3-8b-abliterated-q5_k_m','lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k')) {
    $model=Get-ModelProfile $AppRoot $id
    $previous=Get-ThreadChoice $profile $model
    $threads=Get-PerformanceThreads $model $profile $pin $previous
    $settings=Get-PerformanceOptions $model $profile $pin $threads.prompt
    $expected=if ($model.architecture -ceq 'lfm2') {120} elseif ($model.architecture -ceq 'llama') {240} else {180}
    Check ($threads.generation -eq $expected -and $threads.prompt -eq 240 -and $settings.mq_rows -eq 8 -and $settings.mq_cols -eq 4) ($id+': qualified pool/tile policy')
    $vision=Test-ImageModel $model
    Check ($settings.cache_mib -eq $(if ($vision) {64} else {0}) -and $settings.image_max_tokens -eq 0) ($id+': image cache only for vision; full image detail retained')
    $reserved=Add-PerformanceReserve $model $settings
    Check ($reserved.estimated_peak_runtime_mib -eq $model.estimated_peak_runtime_mib+$settings.reserve_mib) ($id+': cache included in automatic memory admission')
    Check ((Get-PerformanceThreads $model $profile ([pscustomobject]@{}) $previous).generation -eq $previous.generation) 'old runner keeps its previous worker policy'
}
$metrics=[pscustomobject]@{};Add-PerformanceMetrics $metrics ([pscustomobject]@{image_cache_hits=1;image_encode_ms=0;image_cache_bytes=4096})
Check ($metrics.image_cache_hits -eq 1 -and $metrics.image_encode_ms -eq 0) 'cache hits and encoder timings retained for application validation'
$rejected=$false;try {Add-PerformanceMetrics $metrics ([pscustomobject]@{image_encode_ms=-1})} catch {$rejected=$true}
Check $rejected 'invalid native image timing rejected'
$script:health=[pscustomobject]@{profile=$profile}
$state=[pscustomobject]@{modern_source_commit='61e97998bf49c2d425563920b7e83e52b5ae57a6';modern_runtime_id='phichat142-modern-910493bed33a64fd'}
foreach ($file in Get-ChildItem (Join-Path $AppRoot 'config/models') -Filter '*.yaml') {
    $model=Read-JsonFile $file.FullName
    $selected=Get-PrimingPayload $model $state
    $qualified=$model.id -cin @('llama-3.3-8b-abliterated-q5_k_m','huihui-step3-vl-10b-abliterated-q5_k_m')
    $visionTuning=$model.id -ceq 'huihui-step3-vl-10b-abliterated-q5_k_m'
    Check (($selected.runner_file -ceq 'phi-prime-step3-tiles4') -eq $qualified) ($model.id+': qualified runner pairing or decode3 fallback')
    $options=Get-PerformanceOptions $model $profile $selected 240
    Check ($options.wide16 -eq [int]$qualified -and $options.text_pair -eq [int]$qualified -and $options.f32_tile -eq [int]$visionTuning -and $options.q6_panel8 -eq [int]$visionTuning -and $options.f16_conv -eq [int]$visionTuning -and $options.f32_attn -eq [int]($model.id -ceq 'huihui-step3-vl-10b-abliterated-q5_k_m')) ($model.id+': attention tuning cannot leak to another model')
}
Write-Output 'PASS: resident runtime integration policies; no card access.'
