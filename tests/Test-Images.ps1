#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/ChatSessions.ps1')
. (Join-Path $AppRoot 'lib/JobProtocol.ps1')
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw ('FAIL: '+$Message) }; Write-Output ('PASS: '+$Message) }
function Reject([scriptblock]$Action,[string]$Message) { $failed=$false; try {& $Action | Out-Null} catch {$failed=$true}; Check $failed $Message }
$null=New-Item -ItemType Directory -Path $Scratch -Force
Add-Type -AssemblyName System.Drawing
$source=Join-Path $Scratch 'image with spaces.png'
$bitmap=New-Object Drawing.Bitmap(120,80)
$drawing=[Drawing.Graphics]::FromImage($bitmap)
try { $drawing.Clear([Drawing.Color]::CornflowerBlue); $bitmap.Save($source,[Drawing.Imaging.ImageFormat]::Png) } finally {$drawing.Dispose();$bitmap.Dispose()}
$im=Import-ChatImage $Scratch $source
Check ((Assert-StoredImage $Scratch $im) -and $im.width -eq 120 -and $im.height -eq 80) 'image copied into verified session storage'
$model=Get-ModelProfile $AppRoot 'step3-vl-10b-q5_k_m'
$messages=@([pscustomobject]@{role='user';content='Look';images=@($im)},[pscustomobject]@{role='assistant';content='A picture'},[pscustomobject]@{role='user';content='What color?'})
$prompt=New-ChatPrompt $model $messages '' 0
Check ($prompt.images.Count -eq 1 -and $prompt.images[0].id -ceq $im.id -and ([regex]::Matches($prompt.text,'<__media__>')).Count -eq 1) 'follow-up replays image with its original user turn'
Check ($prompt.text.EndsWith("assistant`n<think>`n")) 'Step3 thinking prefix is preserved'
$many=@([pscustomobject]@{role='user';content='Old';images=@($im,$im,$im,$im)},[pscustomobject]@{role='assistant';content='Answer'},[pscustomobject]@{role='user';content='New';images=@($im)})
$trim=New-ChatPrompt $model $many '' 0
Check ($trim.omitted_pairs -eq 1 -and $trim.images.Count -eq 1 -and !$trim.text.Contains('Old')) 'runtime image limit trims complete old turns and their image references together'
$request=[pscustomobject]@{protocol_version=2;action='Chat';messages=$messages}
Assert-PhiJobProtocol $request
$request.protocol_version=1
Reject {Assert-PhiJobProtocol $request} 'old protocol cannot silently discard image input'
$bad=$im.PSObject.Copy(); $bad.id='../secret'
Reject {Get-ImagePath $Scratch $bad} 'image references cannot escape owned storage'
Reject {New-ChatPrompt (Get-ModelProfile $AppRoot 'lfm2.5-2.6b-q5_k_m') $messages ''} 'text models reject image requests'
$session=New-ChatSession $model.id; $session.images=@($im)
$file=Join-Path $Scratch 'sessions.json'
Save-ChatSessions $file 'card/boot' @{$session.id=$session} $session.id
$restored=Read-ChatSessions $file 'card/boot' @($model.id)
Check ($restored.sessions[$session.id].images[0].id -ceq $im.id) 'image drafts survive reopening'
Remove-UnreferencedImages $Scratch @($session)
Check (Test-Path (Get-ImagePath $Scratch $im)) 'active image draft retained'

# Real WPF controls, no timer or hardware access.
Write-JsonFile (Join-Path $AppRoot 'config/connection.yaml') ([pscustomobject]@{data_dir=$Scratch})
$code=[IO.File]::ReadAllText((Join-Path $AppRoot 'Start-PhiChat.ps1')).Replace('$PSScriptRoot',"'$($AppRoot.Replace("'","''"))'").Replace('$timer.Start()','').Replace('[void]$window.ShowDialog()','')
. ([scriptblock]::Create($code))
$profile=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
Accept-CardSession ([pscustomobject]@{serial='TEST';boot_id='boot';profile=$profile;temperature_c=40;memory=[pscustomobject]@{available_kib=12000000}})
$controls.Model.SelectedItem=@($controls.Model.ItemsSource | Where-Object name -CEQ $model.id)[0]
Add-ImageFiles @($source)
Check ($controls.Attachments.Children.Count -eq 1 -and $window.AllowDrop) 'attachment picker/drop path renders a thumbnail'
$script:loadedSelection=$model.id; $script:loadedModel=[pscustomobject]@{serial='TEST'}
Update-ActionControls
Check $controls.Send.IsEnabled 'image-only message can be sent'
$remove=$controls.Attachments.Children[0].Children[1]
$remove.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
Check ($script:conversation.images.Count -eq 0 -and !$controls.Send.IsEnabled) 'remove button clears attachment and disables empty send'
Add-ImageFiles @($source)
$attached=$script:conversation.images[0]
$null=Add-ChatBubble 'user' 'What color is this?' @($attached)
$script:conversation.images=@(); Show-Attachments
$answer=Add-ChatBubble 'assistant' '<think>Inspecting the image.</think>The picture is blue.'
$answer.state='done'; Show-ChatBubbles
$window.Content.Measure((New-Object Windows.Size(1180,820))); $window.Content.Arrange((New-Object Windows.Rect(0,0,1180,820))); $window.Content.UpdateLayout()
$render=New-Object Windows.Media.Imaging.RenderTargetBitmap(1180,820,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$render.Render($window.Content); $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
$output=[IO.File]::Create((Join-Path $Scratch 'image-chat-preview.png')); try {$encoder.Save($output)} finally {$output.Dispose()}
Clear-CardSessions
Check (@(Get-ChildItem (Join-Path $Scratch 'attachments') -File).Count -eq 0) 'offline clears image files along with conversations'
$window.Close()
