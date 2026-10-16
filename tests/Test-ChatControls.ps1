#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$null=New-Item -ItemType Directory -Path $Scratch -Force
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
Write-JsonFile (Join-Path $AppRoot 'config/connection.yaml') ([pscustomobject]@{data_dir=$Scratch})
$source=[IO.File]::ReadAllText((Join-Path $AppRoot 'Start-PhiChat.ps1'))
$source=$source.Replace('$PSScriptRoot',"'$($AppRoot.Replace("'","''"))'").Replace('$timer.Start()','').Replace('[void]$window.ShowDialog()','')
. ([scriptblock]::Create($source))
$profile=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
Accept-CardSession ([pscustomobject]@{serial='TEST';boot_id='boot';profile=$profile;temperature_c=42;memory=[pscustomobject]@{available_kib=12000000}})
$script:nextProbe=[DateTime]::UtcNow.AddHours(1)
$script:loadedModel=[pscustomobject]@{serial='TEST';resources=[pscustomobject]@{context_tokens=1000;batch_tokens=128}}
$script:loadedSelection=$script:selectedModel
function Start-PhiBackendJob {
    param($AppRoot,$DataDirectory,$Request)
    $script:lastSubmittedRequest=$Request
    $directory=Join-Path $Scratch ([Guid]::NewGuid().ToString('N')); $null=New-Item -ItemType Directory $directory
    $process=[pscustomobject]@{HasExited=$false;ExitCode=0}; $process | Add-Member ScriptMethod Dispose {}
    return [pscustomobject]@{process=$process;directory=$directory}
}
function Confirm-ChatDeletion { return $script:confirmDelete }
function Show-ChatRenameDialog { return $script:renameValue }
# Older previews have no metrics or custom-title fields.
$legacy=New-ChatSession $script:selectedModel
$legacy.PSObject.Properties.Remove('custom_title'); $legacy.PSObject.Properties.Remove('metrics')
$legacyFile=Join-Path $Scratch 'legacy.json'
Write-JsonFile $legacyFile ([pscustomobject]@{schema_version=1;epoch=$script:sessionEpoch;selected=$legacy.id;sessions=@($legacy)})
$restored=Read-ChatSessions $legacyFile $script:sessionEpoch @($legacy.model)
Check ($restored.sessions.ContainsKey($legacy.id) -and $null -eq $restored.sessions[$legacy.id].metrics) 'previous preview histories remain readable'
$script:confirmDelete=$true; $script:renameValue='  My   renamed chat  '
$first=$script:conversation
Rename-Conversation $first
Check ($first.title -ceq 'My renamed chat' -and $first.custom_title) 'rename normalizes whitespace and preserves custom names'
$script:renameValue=$null; Rename-Conversation $first
Check ($first.title -ceq 'My renamed chat') 'cancelled rename leaves the title unchanged'
$rejected=$false; try { Rename-ChatSession $first '   ' } catch { $rejected=$true }
Check $rejected 'empty titles are rejected'
Rename-ChatSession $first 'New chat'
$controls.ThinkingDepth.SelectedValue='light'
Check ($first.thinking_depth -ceq 'light' -and $controls.ThinkingDepth.Visibility -eq 'Visible') 'thinking picker updates this chat preference'
$controls.Input.Text='A different automatic title'; Update-ActionControls; Start-JobAction 'Chat'
Check ($script:lastSubmittedRequest.thinking_depth -ceq 'light' -and !$controls.ThinkingDepth.IsEnabled -and $script:lastSubmittedRequest.output_tokens -eq 0) 'Send snapshots thinking preference without imposing a reply cap'
Check ($first.title -ceq 'New chat' -and $first.locked) 'an explicitly chosen New chat name survives first-prompt naming'
$job=$script:active
Write-JsonFile (Join-Path $job.dir 'prompt-budget.json') ([pscustomobject]@{context_tokens=1000;prompt_tokens=200;omitted_pairs=2})
Write-JsonFile (Join-Path $job.dir 'live-progress.json') ([pscustomobject]@{stage='check';native=[pscustomobject]@{Stage='check';Consumed=900;SampleSeconds=90}})
Update-JobInsights $job $null $false
Check ($first.metrics.output_tokens -eq 0 -and $null -eq $first.metrics.generation_tps) 'native precheck counts never masquerade as output tokens'
Write-JsonFile (Join-Path $job.dir 'live-progress.json') ([pscustomobject]@{stage='vision';native=[pscustomobject]@{Stage='vision';Consumed=0;SampleSeconds=100}})
Update-JobInsights $job $null $false
Check ($first.metrics.phase -ceq 'Processing images' -and $first.metrics.output_tokens -eq 0) 'image encoding has its own progress phase'
function Sample([double]$Seconds,[int]$Consumed,[string]$Stage='generating') {
    Write-JsonFile (Join-Path $job.dir 'live-progress.json') ([pscustomobject]@{stage=$Stage;native=[pscustomobject]@{Stage='prefill';Consumed=$Consumed;SampleSeconds=$Seconds}})
    Update-JobInsights $job $null $false; Update-ChatInsights
}
Sample 10 210
Sample 12 216
Check ($first.metrics.output_tokens -eq 16 -and !$first.metrics.output_estimated -and $first.metrics.generation_tps -eq 3) 'live rate uses native token deltas and excludes prompt tokens'
Check ($controls.ContextLabel.Text -ceq '21%' -and $controls.ContextUsage.ToolTip.Contains('216 / 1,000') -and $controls.ContextUsage.ToolTip.Contains('2 older')) 'context ring reports sent context and explains omitted history'
$controls.Input.Text='This is an unsent draft'; Update-ChatInsights
Check ($controls.ContextLabel.Text -ceq '21%') 'unsent drafts do not inflate measured context'
$controls.Statistics.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
Check ($controls.StatisticsPanel.Visibility -eq 'Visible') 'statistics button opens the panel'
$controls.Statistics.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
Check ($controls.StatisticsPanel.Visibility -eq 'Collapsed') 'statistics button closes the panel'
Reset-ChatConversation; $second=$script:conversation
Check ($second.thinking_depth -ceq 'standard') 'new chat starts with standard thinking'
Sample 14 222
Check ($controls.StatsOutput.Text -ceq '--' -and $controls.ContextLabel.Text -ceq '0%') 'background telemetry does not leak into another chat'
Select-Conversation $first
Check ($controls.ThinkingDepth.SelectedValue -ceq 'light') 'chat navigation restores its thinking preference'
Check ($controls.StatsOutput.Text -ceq '22') 'returning to a chat restores its own statistics'
$status=[pscustomobject]@{state='done';result=[pscustomobject]@{generation_tokens=30;generation_tps=3.25;prompt_tps=15.5;context=1000}}
Update-JobInsights $job $status $true; Update-ChatInsights
Check ($first.metrics.output_tokens -eq 30 -and $controls.Speed.Text -ceq '3.3 tokens/s' -and $controls.StatsNote.Text.Contains('measured')) 'final native timing replaces live sampled metrics'
Save-Sessions
$saved=Read-ChatSessions $script:sessionFile $script:sessionEpoch @($first.model)
Check ($saved.sessions[$first.id].custom_title -and $saved.sessions[$first.id].metrics.output_tokens -eq 30) 'rename and per-chat statistics survive same-boot reopen'
$script:confirmDelete=$false; Remove-Conversation $first
Check ($script:sessions.ContainsKey($first.id) -and !(Test-Path (Join-Path $job.dir 'cancel'))) 'cancelled deletion leaves the response and history intact'
$script:confirmDelete=$true; Remove-Conversation $first
Check (!$script:sessions.ContainsKey($first.id) -and $script:conversation.id -ceq $second.id -and (Test-Path (Join-Path $job.dir 'cancel'))) 'deleting the active chat requests Stop and selects a remaining chat'
Write-JsonFile (Join-Path $job.dir 'status.json') ([pscustomobject]@{state='cancelled';message='Response stopped';preserve_ready=$true})
$job.process.HasExited=$true; Update-ChatJobs
$saved=Read-ChatSessions $script:sessionFile $script:sessionEpoch @($first.model)
Check (!$saved.sessions.ContainsKey($first.id) -and $null -ne $script:loadedModel -and $null -eq $script:active) 'late completion cannot resurrect a deleted chat or discard readiness'
Remove-Conversation $second
Check ($script:sessions.Count -eq 1 -and $script:conversation.id -cne $second.id -and !$script:conversation.locked) 'deleting the last chat creates a usable empty chat'

# Exercise the actual routed row menu; no prompts or native processes are used.
function Find-MenuButton($Node) {
    if ($Node -is [Windows.Controls.Button] -and $Node.Tag -ceq 'ChatMenu') { return $Node }
    for ($i=0;$i -lt [Windows.Media.VisualTreeHelper]::GetChildrenCount($Node);$i++) {
        $found=Find-MenuButton ([Windows.Media.VisualTreeHelper]::GetChild($Node,$i))
        if ($found) { return $found }
    }
    return $null
}
$controls.ContextUsage.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
$script:conversation.metrics=New-ChatMetrics
$m=$script:conversation.metrics; $m.context_tokens=1000; $m.prompt_tokens=700; $m.output_tokens=230; $m.output_estimated=$false
$m.generation_tps=2.8; $m.generation_estimated=$false; $m.prompt_tps=13.5; $m.elapsed_seconds=83; $m.phase='Generating'
Update-ChatInsights
$culture=[Threading.Thread]::CurrentThread.CurrentCulture
try { [Threading.Thread]::CurrentThread.CurrentCulture='de-DE'; Update-ChatInsights; Check ($controls.ContextArc.Data.ToString().Length -gt 0) 'ring geometry is independent of locale' }
finally { [Threading.Thread]::CurrentThread.CurrentCulture=$culture }
Update-ChatInsights
foreach ($size in @(@(1180,820),@(820,560))) {
    $w=$size[0];$h=$size[1];$window.Width=$w;$window.Height=$h
    $window.Content.Measure((New-Object Windows.Size($w,$h))); $window.Content.Arrange((New-Object Windows.Rect(0,0,$w,$h))); $window.Content.UpdateLayout()
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap($w,$h,96,96,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($window.Content);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create((Join-Path $Scratch ("controls-$w.png"))); try {$encoder.Save($stream)} finally {$stream.Dispose()}
}
$button=Find-MenuButton $controls.Recent
Check ($null -ne $button) 'each rendered chat row exposes its options button'
$button.RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.Button]::ClickEvent)))
Check ($button.ContextMenu.Items.Count -eq 2) 'row menu offers Rename and Delete chat'
$script:renameValue='Named from menu'
$button.ContextMenu.Items[0].RaiseEvent((New-Object Windows.RoutedEventArgs([Windows.Controls.MenuItem]::ClickEvent)))
Check ($script:conversation.title -ceq 'Named from menu') 'row menu targets its bound conversation'
$button.ContextMenu.IsOpen=$false
$m.prompt_tokens=1200; Update-ChatInsights
Check ($controls.ContextFull.Visibility -eq 'Visible' -and $controls.ContextLabel.Text -ceq '100%') 'a full context renders a complete ring without percentage overflow'
$m.prompt_tokens=1; $m.output_tokens=0; Update-ChatInsights
Check ($controls.ContextLabel.Text -ceq '<1%') 'small nonzero usage remains distinguishable from an empty chat'
$residentDirectory=Join-Path $Scratch 'jobs/job-20261013-130000-abcdefab';$null=New-Item -ItemType Directory $residentDirectory
$reference=[pscustomobject]@{directory=$residentDirectory;token=('a'*32);owner_pid=$PID}
$script:loadedModel | Add-Member resident $reference -Force
$state=[pscustomobject]@{state='priming';token=$reference.token;owner_pid=$PID;worker_pid=$PID;worker_start_ticks=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks}
Write-JsonFile (Join-Path $residentDirectory 'resident.json') $state
$controls.Input.Text='Continue after Stop';Show-SelectedModelState
Check (!$controls.Send.IsEnabled -and $controls.Input.IsEnabled -and $controls.LoadStatus.Text -ceq 'Priming...') 'background priming disables Send while keeping the composer usable'
$state.state='ready';Write-JsonFile (Join-Path $residentDirectory 'resident.json') $state;Show-SelectedModelState
Check ($controls.Send.IsEnabled -and $controls.LoadStatus.Text.StartsWith('Primed:')) 'resident readiness restores Send without opening a new chat'
Clear-CardSessions
Check (Test-Path -LiteralPath (Join-Path $residentDirectory 'cancel')) 'card-session invalidation signals the owned resident worker'
Check ($controls.ContextLabel.Text -ceq '--' -and $controls.StatsOutput.Text -ceq '--') 'offline clears context usage and statistics'
$window.Close()
