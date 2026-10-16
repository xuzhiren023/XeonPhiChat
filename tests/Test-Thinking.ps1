param([string]$AppRoot=(Join-Path (Split-Path $PSScriptRoot -Parent) 'app'),[string]$Scratch=(Join-Path $env:TEMP ('phi-thinking-'+[Guid]::NewGuid().ToString('N'))))
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/ChatSessions.ps1')
. (Join-Path $AppRoot 'lib/JobProtocol.ps1')
function Check($Value,[string]$Message) {if(!$Value){throw $Message}}
$model=Get-ModelProfile $AppRoot 'huihui-step3-vl-10b-abliterated-q5_k_m'
$image=[pscustomobject]@{id=('a'*32);sha256=('b'*64);name='test.png';bytes=123;width=32;height=24}
$messages=@([pscustomobject]@{role='user';content='Identify this shape.';images=@($image)})
$standard=New-ChatPrompt $model $messages 'Be helpful.' 0
$light=New-ChatPrompt $model $messages 'Be helpful.' 0 -ThinkingDepth light
$extended=New-ChatPrompt $model $messages 'Be helpful.' 0 -ThinkingDepth extended
Check ($standard.text -ceq (New-ChatPrompt $model $messages 'Be helpful.' 0 -ThinkingDepth standard).text) 'Default prompt changed.'
Check ($light.text.Contains('Reasoning effort: light.') -and $extended.text.Contains('Reasoning effort: extended.')) 'Selected effort did not reach prompt.'
Check ($light.images.Count -eq 1 -and $light.images[0].id -ceq $image.id -and $light.text.Contains('<__media__>Identify this shape.')) 'Image input changed.'
Check ($messages[0].content -ceq 'Identify this shape.' -and !$messages[0].PSObject.Properties['thinking_depth']) 'Conversation message mutated.'
Check ($light.text.EndsWith("<think>`n") -and (Test-PromptStartsThinking $model)) 'Huihui reasoning prefix or rendering differs.'
$history=@([pscustomobject]@{role='user';content=('x'*270000)},[pscustomobject]@{role='assistant';content='Previous reply.'})+$messages
$trimmed=New-ChatPrompt $model $history 'Be helpful.' 0 -ThinkingDepth extended
Check ($trimmed.omitted_pairs -eq 1 -and ([regex]::Matches($trimmed.text,'Reasoning effort: extended\.')).Count -eq 1) 'History trim lost or repeated effort.'
$plain=Get-ModelProfile $AppRoot 'lfm2.5-vl-3b-q5_k_m'
Check (!(Test-ThinkingModel $plain)) 'Non-thinking model advertises effort.'
$rejected=$false;try{$null=New-ChatPrompt $plain $messages '' 0 -ThinkingDepth light}catch{$rejected=$true};Check $rejected 'Unsupported effort accepted.'
$rejected=$false;try{Assert-PhiJobProtocol ([pscustomobject]@{action='Chat';thinking_depth='invalid';messages=$messages})}catch{$rejected=$true};Check $rejected 'Invalid request accepted.'
Check ((Get-ThinkingDepth ([pscustomobject]@{})) -ceq 'standard') 'Old request not compatible.'
$null=New-Item -ItemType Directory $Scratch -Force
$session=New-ChatSession $model.id;$session.thinking_depth='extended'
$path=Join-Path $Scratch 'sessions.json'
Save-ChatSessions $path 'card/boot' @{$session.id=$session} $session.id
$saved=Read-ChatSessions $path 'card/boot' @($model.id)
Check ($saved.sessions[$session.id].thinking_depth -ceq 'extended') 'Session preference not restored.'
Add-Type -AssemblyName PresentationFramework
[xml]$xaml=Get-Content (Join-Path $AppRoot 'ChatWindow.xaml') -Raw -Encoding UTF8
$window=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($xaml)))
$control=$window.FindName('ThinkingDepth');Check ($control.Items.Count -eq 3) 'Thinking picker missing.'
$control.SelectedValue='extended';Check ($control.SelectedItem.Content -ceq 'Thinking: Extended') 'Picker mapping differs.'
$window.Close()
Write-Output 'PASS: thinking preference, image/history preservation, session restore, request validation and WPF picker.'
