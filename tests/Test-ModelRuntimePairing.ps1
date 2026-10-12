#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Check([bool]$Value,[string]$Message) { if (!$Value) {throw "FAIL: $Message"}; Write-Output "PASS: $Message" }
$null=New-Item -ItemType Directory $Scratch -Force
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
$p=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
$small=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-3120a.yaml')
$runtime=[pscustomobject]@{modern_features=@('auto-resources-v1','q5-balanced-pf64-v1')}
$expected=@{'lfm2.5-2.6b-matrices-q5_k'=@('optimized',120);'llama-3.3-8b-abliterated-matrices-q5_k'=@('optimized',240);
    'lfm2.5-2.6b-q5_k_m'=@('standard',180);'llama-3.3-8b-abliterated-q5_k_m'=@('standard',180);
    'llama-3.3-8b-abliterated-q2_k'=@('standard',180);'tinydolphin-q5_k_m'=@('historical',240)}
foreach($id in $expected.Keys) {
    $m=Get-ModelProfile $AppRoot $id
    Check ((Get-ModelEngineVariant $m) -ceq $expected[$id][0]) ($id+': explicit engine pairing')
    Check ((Get-ThreadChoice $p $m $runtime).generation -eq $expected[$id][1]) ($id+': paired worker policy')
}
$reject=$false;try{Get-ModelEngineVariant (Get-ModelProfile $AppRoot 'step3-vl-10b-q5_k_m')}catch{$reject=$true}
Check $reject 'unsupported architecture cannot acquire an engine pairing'
$choices=@(Get-ModelChoices $AppRoot $p)
Check (@($choices|Where-Object optimized).Count -eq 2) 'only the two uniform Q5_K models earn the performance check'
Check (@(Get-ModelChoices $AppRoot $small|Where-Object optimized).Count -eq 0) 'unsupported card never shows the performance check'
Check (@(Get-ModelChoices $AppRoot|Where-Object optimized).Count -eq 0) 'unknown hardware never shows the performance check'
$reject=$false;try {Assert-ModelReady ([pscustomobject]@{engine_variant='standard'}) (Get-ModelProfile $AppRoot 'lfm2.5-2.6b-matrices-q5_k') $runtime $null} catch {$reject=$_.Exception.Message -like '*pairing changed*'}
Check $reject 'stale ready state cannot switch a model to another engine'
Write-JsonFile (Join-Path $AppRoot 'config/connection.yaml') ([pscustomobject]@{data_dir=$Scratch})
$source=[IO.File]::ReadAllText((Join-Path $AppRoot 'Start-PhiChat.ps1'))
$source=$source.Replace('$PSScriptRoot',"'$($AppRoot.Replace("'","''"))'").Replace('$timer.Start()','').Replace('[void]$window.ShowDialog()','')
. ([scriptblock]::Create($source))
Accept-CardSession ([pscustomobject]@{serial='TEST';boot_id='boot';profile=$p;temperature_c=42;memory=[pscustomobject]@{available_kib=12000000}})
$fast=New-ChatSession 'lfm2.5-2.6b-matrices-q5_k'
$mixed=New-ChatSession 'lfm2.5-2.6b-q5_k_m'
$script:sessions[$fast.id]=$fast;$script:sessions[$mixed.id]=$mixed
Select-Conversation $fast
Check ($controls.Model.SelectedItem.optimized -and $controls.RuntimeStatus.Text -ceq 'Optimized for fast chat') 'Q5_K selection shows the green performance badge'
Check ($controls.RuntimeStatus.ToolTip -like 'Selected:*') 'selection does not claim an unloaded engine is running'
$script:loadedModel=[pscustomobject]@{serial='TEST';engine_variant='optimized'};$script:loadedSelection=$fast.model
Show-SelectedModelState
Check ($controls.RuntimeStatus.ToolTip -ceq 'Using optimized q5_k runtime.') 'successful Load confirms the actual optimized engine'
Select-Conversation $mixed
Check (!$controls.Model.SelectedItem.optimized -and $controls.RuntimeStatus.Text -ceq 'Standard runtime') 'navigating to mixed weights restores the standard runtime label'
Select-Conversation $fast
Check ($controls.Model.SelectedItem.optimized) 'returning to Q5_K restores its check'
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
