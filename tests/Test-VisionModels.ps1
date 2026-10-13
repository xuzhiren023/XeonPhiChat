#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
function Check([bool]$Value,[string]$Message) {if (!$Value) {throw ('FAIL: '+$Message)};Write-Output ('PASS: '+$Message)}
$model=Get-ModelProfile $AppRoot 'lfm2.5-vl-3b-q5_k_m'
$card=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
$choices=@(Get-ModelChoices $AppRoot $card)
Check (@($choices | Where-Object {$_.name -match 'gaston' -and $_.label -match 'Text only' -and $_.enabled}).Count -eq 1) 'Gaston remains enabled and explicitly labeled text only'
Check (!(Test-ImageModel (Get-ModelProfile $AppRoot 'lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k'))) 'Gaston cannot claim untrained image capability'
Check (@($choices | Where-Object {$_.name -ceq $model.id -and $_.enabled -and $_.engine_variant -ceq 'shared'}).Count -eq 1) 'LFM2.5-VL uses the pinned shared runtime on 7120P'
Check (Test-ImageModel $model) 'LFM2.5-VL accepts image attachments'
$p=Get-ProjectorProfile $model
Check (!$p.local_only -and $p.repository -ceq $model.repository -and $p.revision -ceq $model.revision) 'matching vision component has an immutable automatic download'
$image=[pscustomobject]@{id=('a'*32);name='test.png';bytes=100;sha256=('b'*64);width=120;height=80}
$prompt=New-ChatPrompt $model @([pscustomobject]@{role='user';content='Describe';images=@($image)}) '' 0
Check ($prompt.text.StartsWith('<|startoftext|>') -and $prompt.text.Contains('<__media__>') -and $prompt.text.EndsWith("assistant`n") -and !$prompt.text.Contains('<think>')) 'LFM2.5-VL uses its image template without a thinking prefix'
$resource=Get-VisionResourceModel $model @($image)
Check ($resource.extra_resident_mib -eq [math]::Ceiling($p.file_size_bytes/1MB) -and $resource.estimated_peak_runtime_mib -gt $model.estimated_peak_runtime_mib) 'allocation includes vision file and encoder memory'
