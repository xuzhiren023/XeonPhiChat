#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$null=New-Item -ItemType Directory -Path $Scratch -Force
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/ChatSessions.ps1')
$first=New-ChatSession 'lfm2.5-2.6b-q5_k_m'; $second=New-ChatSession $first.model
Check ($first.id -cne $second.id) 'multiple chats may use the same model'
Lock-ChatSession $first $first.model 'Explain the model memory budget'
$rejected=$false; try { Lock-ChatSession $first 'another-model' 'test' } catch { $rejected=$true }
Check $rejected 'model is fixed after the first prompt'
$first.draft='draft survives navigation'
$null=$first.messages.Add([pscustomobject]@{role='user';content='Question'})
$bubble=[pscustomobject]@{role='assistant';text='';state='streaming';starts_thinking=$true}
$null=$first.bubbles.Add($bubble)
Complete-ChatTurn $first $bubble 'Some reasoning</think>Partial answer' 'stopped'
Check ($first.messages.Count -eq 2 -and $first.messages[-1].content.Contains('Partial answer')) 'Stop preserves the partial response and valid turn order'
$sessions=@{}; $sessions[$first.id]=$first; $sessions[$second.id]=$second
$path=Join-Path $Scratch 'sessions.json'
Save-ChatSessions $path 'CARD/BOOT' $sessions $first.id
$restored=Read-ChatSessions $path 'CARD/BOOT' @($first.model)
Check ($restored.sessions.Count -eq 2 -and $restored.sessions[$first.id].draft -ceq $first.draft) 'same-boot reopen restores separate chats and drafts'
$expired=Read-ChatSessions $path 'CARD/NEWBOOT' @($first.model)
Check ($expired.sessions.Count -eq 0 -and !(Test-Path $path)) 'a new card boot expires saved conversations'
$raw='reasoning</think>Final answer'
for ($i=0;$i -le $raw.Length;$i++) {
    $parts=Split-AssistantContent $raw.Substring(0,$i) $true $false
    if ($i -lt $raw.IndexOf('</think>')+8) { Check (!$parts.answer) "split closing tag never leaks reasoning at chunk $i" }
}
$parts=Split-AssistantContent '<think>one</think>Answer <think>two</think> done' $false $true
Check ($parts.reasoning -ceq 'onetwo' -and $parts.answer -ceq 'Answer  done') 'reasoning tags separate from the actual answer'
Check ((Split-AssistantContent 'Ordinary answer' $false $true).reasoning -ceq '') 'non-reasoning models get no invented thought process'

# Load the real window and handlers without showing it, starting a timer, or
# contacting a card. RenderTargetBitmap below is an offscreen WPF render.
Write-JsonFile (Join-Path $AppRoot 'config/connection.yaml') ([pscustomobject]@{data_dir=$Scratch})
$source=[IO.File]::ReadAllText((Join-Path $AppRoot 'Start-PhiChat.ps1'))
$source=$source.Replace('$PSScriptRoot',"'$($AppRoot.Replace("'","''"))'").Replace('$timer.Start()','').Replace('[void]$window.ShowDialog()','')
. ([scriptblock]::Create($source))
$profile=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-3120a.yaml')
$card=[pscustomobject]@{serial='TEST';boot_id='boot';profile=$profile;temperature_c=42;memory=[pscustomobject]@{available_kib=4000000}}
Accept-CardSession $card
$script:loadedModel=[pscustomobject]@{serial='TEST';resources=[pscustomobject]@{context_tokens=7168;batch_tokens=128}}
$script:loadedSelection=$script:selectedModel
function Start-PhiBackendJob {
    $directory=Join-Path $Scratch ([Guid]::NewGuid().ToString('N')); $null=New-Item -ItemType Directory $directory
    $process=[pscustomobject]@{HasExited=$false;ExitCode=0}
    $process | Add-Member ScriptMethod Dispose {}
    return [pscustomobject]@{process=$process;directory=$directory}
}
$controls.Input.Text='How does attention use memory?'; Update-ActionControls
Start-JobAction 'Chat'
Check ($null -ne $script:active -and !$controls.Model.IsEnabled) 'first prompt starts a job and locks the model'
$origin=$script:conversation; $job=$script:active
Reset-ChatConversation
Check ($script:conversation.id -cne $origin.id -and $script:sessions.ContainsKey($origin.id)) 'New chat preserves the previous chat during streaming'
$controls.Input.Text='Unsent second chat'
Write-Utf8 (Join-Path $job.dir 'response.txt') 'Checking the allocation.</think>The KV cache grows with context.'
$script:nextProbe=[DateTime]::UtcNow.AddHours(1)
Update-ChatJobs
Check ($origin.bubbles[-1].text.Contains('KV cache') -and $script:conversation.bubbles.Count -eq 0) 'background output stays in the originating chat'
Write-JsonFile (Join-Path $job.dir 'status.json') ([pscustomobject]@{state='cancelled';preserve_ready=$true;message='Response stopped';progress=$null})
$job.process.HasExited=$true
Update-ChatJobs
Check ($origin.messages.Count -eq 2 -and $null -ne $script:loadedModel -and $null -eq $script:active) 'cancel completion retains readiness and unlocks the composer'
Select-Conversation $origin
$controls.Input.Text='Continue'; Update-ActionControls
Check $controls.Send.IsEnabled 'a follow-up can be sent in the stopped conversation'
Check ($script:sessions.Values.Where({$_.draft -ceq 'Unsent second chat'}).Count -eq 1) 'navigation keeps the other chat draft'

foreach ($action in @('Health','InstallModern')) {
    Start-JobAction $action
    $job=$script:active
    Write-JsonFile (Join-Path $job.dir 'status.json') ([pscustomobject]@{state='running';message='Restoring the accepted runtime: checking startup.';progress=$null})
    Update-ChatJobs
    Check ($controls.Status.Text -ceq 'Restoring the accepted runtime: checking startup.') ($action+' displays runtime restoration progress')
    $controls.Stop.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
    Update-ChatJobs
    Check ($controls.Status.Text -ceq 'Cancelling...' -and (Test-Path (Join-Path $job.dir 'cancel'))) ($action+' keeps cancellation visible while cleanup finishes')
    Write-JsonFile (Join-Path $job.dir 'status.json') ([pscustomobject]@{state='cancelled';message='Runtime restoration cancelled';preserve_ready=$false;progress=$null})
    $job.process.HasExited=$true
    Update-ChatJobs
    Check ($null -eq $script:active -and $controls.Status.Text -ceq 'Runtime restoration cancelled' -and $controls.Connect.IsEnabled) ($action+' cancellation permits reconnect and is not labelled Connected')
}

$window.Width=1180; $window.Height=820
$window.Content.Measure((New-Object Windows.Size(1180,820)))
$window.Content.Arrange((New-Object Windows.Rect(0,0,1180,820)))
$window.Content.UpdateLayout()
$bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap(1180,820,96,96,[Windows.Media.PixelFormats]::Pbgra32)
$bitmap.Render($window.Content)
$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
$stream=[IO.File]::Create((Join-Path $Scratch 'chat-preview.png')); try {$encoder.Save($stream)} finally {$stream.Dispose()}
Clear-CardSessions
Check ($script:sessions.Count -eq 1 -and !$script:sessionEpoch -and !(Test-Path $script:sessionFile) -and !$controls.Send.IsEnabled) 'offline clears recent conversations and readiness'
$window.Close()
