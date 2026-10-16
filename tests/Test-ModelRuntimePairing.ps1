#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Check([bool]$Value,[string]$Message) { if (!$Value) {throw "FAIL: $Message"}; Write-Output "PASS: $Message" }
$null=New-Item -ItemType Directory $Scratch -Force
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
$p=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
$small=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-3120a.yaml')
$runtime=[pscustomobject]@{modern_features=@('auto-resources-v1','shared-multi-quant-v1')}
$expected=@{'lfm2.5-2.6b-matrices-q5_k'=@('shared',180);'llama-3.3-8b-abliterated-matrices-q5_k'=@('shared',180);
    'lfm2.5-2.6b-q5_k_m'=@('shared',180);'llama-3.3-8b-abliterated-q5_k_m'=@('shared',180);
    'llama-3.3-8b-abliterated-q2_k'=@('shared',180);'tinydolphin-q5_k_m'=@('shared',180)}
foreach($id in $expected.Keys) {
    $m=Get-ModelProfile $AppRoot $id
    Check ((Get-ModelEngineVariant $m) -ceq $expected[$id][0]) ($id+': explicit engine pairing')
    Check ((Get-ThreadChoice $p $m $runtime).generation -eq $expected[$id][1]) ($id+': paired worker policy')
    Assert-ModelRuntimeFeatures $m $runtime
    $reject=$false;try{Assert-ModelRuntimeFeatures $m ([pscustomobject]@{modern_features=@('q5-balanced-pf64-v1')})}catch{$reject=$true}
    Check $reject ($id+': old Q5-only runtime cannot silently run this selection')
    Check ((Get-ThreadChoice $small $m $runtime).generation -eq 168) ($id+': 3120A policy respects its cores')
}
$tiny=Get-ModelProfile $AppRoot 'tinydolphin-q5_k_m'
$policy=Get-ThreadChoice $p $tiny $runtime
Check ($policy.prompt -eq 180 -and $policy.mq_rows -eq 4) 'Rebased TinyDolphin starts with the same conservative policy as other models'
$prompt=New-ChatPrompt $tiny @([pscustomobject]@{role='user';content='hello'}) 'system'
Check ($prompt.text.StartsWith('<|im_start|>system') -and !$prompt.text.Contains('<|start_header_id|>')) 'TinyDolphin retains ChatML on the new engine'
$unknown=(Get-ModelProfile $AppRoot 'huihui-step3-vl-10b-abliterated-q5_k_m').PSObject.Copy(); $unknown.architecture='unsupported'
$reject=$false;try{Get-ModelEngineVariant $unknown}catch{$reject=$true}
Check $reject 'unsupported architecture cannot acquire an engine pairing'
$choices=@(Get-ModelChoices $AppRoot $p)
Check (@($choices|Where-Object optimized).Count -eq 0) 'performance check follows the new engine evidence, not old Q5-only qualification'
Check (@(Get-ModelChoices $AppRoot $small|Where-Object optimized).Count -eq 0) 'unsupported card never shows the performance check'
Check (@(Get-ModelChoices $AppRoot|Where-Object optimized).Count -eq 0) 'unknown hardware never shows the performance check'
$reject=$false;try {Assert-ModelReady ([pscustomobject]@{engine_variant='standard'}) (Get-ModelProfile $AppRoot 'lfm2.5-2.6b-matrices-q5_k') $runtime $null} catch {$reject=$_.Exception.Message -like '*pairing changed*'}
Check $reject 'stale ready state cannot switch a model to another engine'
Write-JsonFile (Join-Path $AppRoot 'config/connection.yaml') ([pscustomobject]@{data_dir=$Scratch})
$source=[IO.File]::ReadAllText((Join-Path $AppRoot 'Start-PhiChat.ps1'))
$source=$source.Replace('$PSScriptRoot',"'$($AppRoot.Replace("'","''"))'").Replace('$timer.Start()','').Replace('[void]$window.ShowDialog()','')
. ([scriptblock]::Create($source))
Accept-CardSession ([pscustomobject]@{serial='TEST';boot_id='boot';profile=$p;temperature_c=42;memory=[pscustomobject]@{available_kib=12000000}})
$fast=New-ChatSession 'tinydolphin-q5_k_m'
$mixed=New-ChatSession 'lfm2.5-2.6b-q5_k_m'
$script:sessions[$fast.id]=$fast;$script:sessions[$mixed.id]=$mixed
Select-Conversation $fast
Check (!$controls.Model.SelectedItem.optimized -and $controls.RuntimeStatus.Text -ceq 'Multimodal runtime 61e9799') 'rebased build displays its revision without an inherited performance badge'
Check ($controls.RuntimeStatus.ToolTip -like 'Selected:*') 'selection does not claim an unloaded engine is running'
$script:loadedModel=[pscustomobject]@{serial='TEST';engine_variant='shared'};$script:loadedSelection=$fast.model
Show-SelectedModelState
Check ($controls.RuntimeStatus.ToolTip -ceq 'Using multimodal runtime 61e9799.') 'successful Load confirms the shared engine'
Select-Conversation $mixed
Check (!$controls.Model.SelectedItem.optimized -and $controls.RuntimeStatus.Text -ceq 'Multimodal runtime 61e9799') 'mixed weights use the shared runtime without an inherited performance claim'
Select-Conversation $fast
Check (!$controls.Model.SelectedItem.optimized) 'switching chats does not manufacture a performance qualification'
# Render the selected badge and the small-window layout without opening a window.
foreach($size in @(@(1180,820),@(820,560))) {
    $window.Width=$size[0];$window.Height=$size[1]
    $window.Content.Measure((New-Object Windows.Size($size[0],$size[1])))
    $window.Content.Arrange((New-Object Windows.Rect(0,0,$size[0],$size[1])));$window.Content.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap($size[0],$size[1],96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($window.Content)
    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $Scratch ('pairing-'+$size[0]+'.png')))
    try {$encoder.Save($stream)}finally{$stream.Dispose()}
}
Clear-CardSessions
Check ($controls.RuntimeStatus.Visibility -eq 'Collapsed' -and !$controls.Model.SelectedItem.optimized) 'offline clears the check and active runtime claim'
