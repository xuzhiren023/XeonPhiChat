#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/BackendClient.ps1')
. (Join-Path $PSScriptRoot 'lib/ChatSessions.ps1')
. (Join-Path $PSScriptRoot 'lib/ChatView.ps1')
. (Join-Path $PSScriptRoot 'lib/ChatInsights.ps1')
$script:appRoot=$PSScriptRoot
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
try {
    if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') { throw 'Launch with powershell.exe -STA -File Start-PhiChat.ps1.' }
    $connection=Read-PhiConnection $PSScriptRoot
    $cfg=Read-JsonFile (Join-Path $PSScriptRoot 'config/app.yaml')
} catch { [void][Windows.MessageBox]::Show($_.Exception.Message,'Phi Chat setup'); exit 1 }
[xml]$xaml=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatWindow.xaml') -Raw -Encoding UTF8
$reader=New-Object Xml.XmlNodeReader($xaml)
$window=[Windows.Markup.XamlReader]::Load($reader)
$window.Title='Phi Chat '+([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'VERSION')).Trim())
$controls=@{}
foreach ($name in @('Model','Connect','Load','Restore','LoadStatus','LoadProgress','ResourceInfo','ThermalStatus','MemoryStatus','Speed','Forecast','ChatScroll','ChatMessages','Transcript','Input','Send','Stop','New','Save','Evidence','Status','Recent','Welcome','ConnectionState','Statistics','StatisticsPanel','StatsState','PromptSpeed','StatsElapsed','StatsOutput','StatsPrompt','StatsContext','StatsNote','ContextUsage','ContextArc','ContextFull','ContextLabel','RuntimeStatus')) { $controls[$name]=$window.FindName($name) }
$modelChoices=@(Get-ModelChoices $PSScriptRoot)
$controls.Model.ItemsSource=$modelChoices
$default=@($modelChoices | Where-Object { $_.name -ceq $cfg.default_model })
$controls.Model.SelectedItem=if ($default.Count) { $default[0] } else { $modelChoices[0] }
$script:selectedModel=$controls.Model.SelectedItem.name
$script:sessions=@{}; $script:conversation=New-ChatSession $script:selectedModel; $script:sessions[$script:conversation.id]=$script:conversation
$script:sessionEpoch=''; $script:sessionFile=Join-Path $connection.data_dir 'chat-sessions.json'; $script:historyLoaded=$false
$script:connectedSerial=''; $script:connectedProfile=$null; $script:loadedModel=$null; $script:loadedSelection=''
$script:active=$null; $script:probe=$null; $script:nextProbe=[DateTime]::MinValue; $script:lastJob=''; $script:liveBubble=$null
$script:lastMemorySnapshot=$null; $script:updatingModels=$false; $script:updatingRecent=$false; $script:switching=$false; $script:dirty=$false; $script:lastSave=[DateTime]::MinValue
function Show-Problem([string]$Text) { [void][Windows.MessageBox]::Show($window,$Text,'Phi Chat') }
function Save-Sessions {
    if (!$script:sessionEpoch) { return }
    $script:conversation.draft=$controls.Input.Text
    Save-ChatSessions $script:sessionFile $script:sessionEpoch $script:sessions $script:conversation.id
    $script:dirty=$false; $script:lastSave=[DateTime]::UtcNow
}
function Update-RecentChats {
    $script:updatingRecent=$true
    try { $controls.Recent.ItemsSource=@($script:sessions.Values | Sort-Object updated_utc -Descending); $controls.Recent.SelectedItem=$script:conversation }
    finally { $script:updatingRecent=$false }
}
function Update-ModelChoices {
    $script:updatingModels=$true
    try {
        $choices=@(Get-ModelChoices $PSScriptRoot $script:connectedProfile)
        $controls.Model.ItemsSource=$choices
        $controls.Model.SelectedItem=@($choices | Where-Object { $_.name -ceq $script:selectedModel })[0]
    } finally { $script:updatingModels=$false }
}
function Select-Conversation($Session) {
    $script:conversation.draft=$controls.Input.Text
    $script:conversation=$Session; $script:selectedModel=$Session.model
    $script:switching=$true
    try { Update-ModelChoices; $controls.Input.Text=$Session.draft; $controls.Transcript.Text=$Session.transcript }
    finally { $script:switching=$false }
    Show-ChatBubbles; Update-RecentChats; Show-SelectedModelState; Update-ForecastPreview; Update-ChatInsights
    $script:dirty=$true
}
function Reset-ChatConversation {
    $session=New-ChatSession $script:selectedModel; $script:sessions[$session.id]=$session
    Select-Conversation $session
    $controls.Status.Text='New chat'; $controls.Input.Focus() | Out-Null
}
function Rename-Conversation($Session) {
    $title=Show-ChatRenameDialog $Session.title
    if ($null -eq $title) { return }
    Rename-ChatSession $Session $title
    Update-RecentChats; Save-Sessions
}
function Remove-Conversation($Session) {
    if (!(Confirm-ChatDeletion $Session.title)) { return }
    if ($script:active -and $script:active.action -ceq 'Chat' -and $script:active.conversation.id -ceq $Session.id) {
        Stop-PhiBackendJob $script:active.dir; $script:active.stopRequested=$true
    }
    $script:sessions.Remove($Session.id)
    if ($script:conversation.id -ceq $Session.id) {
        if ($script:sessions.Count) { Select-Conversation @($script:sessions.Values | Sort-Object updated_utc -Descending)[0] }
        else { Reset-ChatConversation }
    }
    Update-RecentChats; Update-ActionControls; Save-Sessions
}
function Test-SelectedReady {
    return ($null -ne $script:loadedModel -and $script:loadedSelection -ceq $script:selectedModel -and $script:loadedModel.serial -ceq $script:connectedSerial)
}
function Update-ModelRuntimeStatus {
    $choice=$controls.Model.SelectedItem
    if (!$script:connectedSerial -or !$choice -or !$choice.enabled) {
        $controls.RuntimeStatus.Visibility='Collapsed'
        return
    }
    $controls.RuntimeStatus.Visibility='Visible'
    $label=switch ($choice.engine_variant) {'optimized' {'Optimized Q5_K runtime'} 'standard' {'Standard runtime'} default {'Classic runtime'}}
    $using=((Test-SelectedReady) -and $script:loadedModel.PSObject.Properties['engine_variant'] -and $script:loadedModel.engine_variant -ceq $choice.engine_variant)
    $controls.RuntimeStatus.Text=if ($choice.optimized) {'Optimized for fast chat'} else {$label}
    $controls.RuntimeStatus.Foreground=if ($choice.optimized) {'#6DDC9F'} else {'#999999'}
    $controls.RuntimeStatus.ToolTip=if ($using) {'Using '+$label.ToLowerInvariant()+'.'} else {'Selected: '+$label+'. Load the model to use it.'}
}
function Update-ActionControls {
    $idle=($null -eq $script:active)
    $available=($idle -and !$script:probe -and $script:connectedSerial -and $script:sessionEpoch -and $null -ne $controls.Model.SelectedItem -and $controls.Model.SelectedItem.enabled)
    $controls.Load.IsEnabled=[bool]$available
    $controls.Send.IsEnabled=([bool]$available -and (Test-SelectedReady) -and ![string]::IsNullOrWhiteSpace($controls.Input.Text))
    $controls.Model.IsEnabled=($idle -and !$script:conversation.locked)
    $controls.Connect.IsEnabled=($idle -and !$script:probe); $controls.Restore.IsEnabled=($idle -and !$script:probe)
    $controls.Stop.Visibility=if ($idle) {'Collapsed'} else {'Visible'}
    $controls.Send.Visibility=if ($idle) {'Visible'} else {'Collapsed'}
    $controls.Stop.IsEnabled=(!$idle -and !$script:active.stopRequested)
    Update-ModelRuntimeStatus
}
function Set-Busy([bool]$Busy) { Update-ActionControls }
function Show-SelectedModelState {
    $controls.LoadStatus.Text=if (Test-SelectedReady) {'Ready: '+$controls.Model.SelectedItem.label} else {'Load '+$controls.Model.SelectedItem.label}
    $controls.Load.Content=if (Test-SelectedReady) {'Reload model'} else {'Load model'}
    Update-ActionControls
}
function Clear-CardSessions {
    $script:sessionEpoch=''; $script:historyLoaded=$false; $script:connectedSerial=''; $script:connectedProfile=$null; $script:loadedModel=$null; $script:loadedSelection=''
    if (Test-Path -LiteralPath $script:sessionFile) { Remove-Item -LiteralPath $script:sessionFile -Force }
    $script:sessions=@{}; $script:conversation=New-ChatSession $script:selectedModel; $script:sessions[$script:conversation.id]=$script:conversation
    $script:dirty=$false
    $controls.Input.Clear(); $controls.Transcript.Clear(); Update-ModelChoices; Show-ChatBubbles; Update-RecentChats; Update-ActionControls; Update-ChatInsights
}
function Accept-CardSession($Card) {
    $epoch=$Card.serial+'/'+$Card.boot_id
    if ($script:sessionEpoch -and $script:sessionEpoch -cne $epoch) { Clear-CardSessions }
    if (!$script:historyLoaded) {
        $saved=Read-ChatSessions $script:sessionFile $epoch @($modelChoices.name)
        if ($saved.sessions.Count) {
            $script:sessions=$saved.sessions
            $chosen=if ($script:sessions.ContainsKey($saved.selected)) {$script:sessions[$saved.selected]} else {@($script:sessions.Values | Sort-Object updated_utc -Descending)[0]}
            Select-Conversation $chosen
        }
        $script:historyLoaded=$true
    }
    $script:sessionEpoch=$epoch; $script:connectedSerial=$Card.serial; $script:connectedProfile=$Card.profile
    $script:lastMemorySnapshot=$Card.memory
    $controls.ConnectionState.Text=$Card.profile.card_model.Replace('Intel Xeon Phi ','').Replace(' class','')+' online'
    $controls.ThermalStatus.Text=('{0} C | automatic thermal protection' -f $Card.temperature_c)
    $controls.ResourceInfo.Text=$Card.profile.card_model
    Update-ModelChoices; Update-ActionControls; Update-ChatInsights
}
function Start-JobAction([string]$Action) {
    if ($script:active -or $script:probe) { return }
    if ($Action -eq 'Chat' -and (!$controls.Send.IsEnabled -or [string]::IsNullOrWhiteSpace($controls.Input.Text))) { return }
    if ($Action -in @('Load','Chat') -and (!$script:connectedSerial -or !$controls.Model.SelectedItem.enabled)) { return }
    $bubble=$null; $session=$script:conversation; $priorTranscript=$session.transcript; $priorMetrics=$session.metrics
    $request=[pscustomobject]@{action=$Action;model=$script:selectedModel;automatic_resources=$true;session_epoch=$script:sessionEpoch;batch=0;context_tokens=0;output_tokens=0;owner_pid=$PID;connected_serial=$script:connectedSerial;ready=$script:loadedModel;messages=@()}
    if ($Action -eq 'Chat') {
        $submitted=$controls.Input.Text
        Lock-ChatSession $session $script:selectedModel $submitted
        $session.metrics=New-ChatMetrics
        $null=$session.messages.Add([pscustomobject]@{role='user';content=$submitted})
        $session.transcript+="YOU`r`n$submitted`r`n`r`nPHI`r`n"
        $null=Add-ChatBubble 'user' $submitted; $bubble=Add-ChatBubble 'assistant' ''
        $controls.Welcome.Visibility='Collapsed'; $controls.Input.Clear(); $session.draft=''
        $request.messages=@($session.messages.ToArray()); Update-RecentChats; Save-Sessions
    }
    try {
        $job=Start-PhiBackendJob $PSScriptRoot $connection.data_dir $request
        $script:active=[pscustomobject]@{process=$job.process;dir=$job.directory;action=$Action;model=$script:selectedModel;conversation=$session;bubble=$bubble;priorTranscript=$priorTranscript;stopRequested=$false;tail=(New-Object PhiChat.Utf8Tail);answer=(New-Object Text.StringBuilder);watch=[Diagnostics.Stopwatch]::StartNew();rate=(New-Object PhiChat.TextRate);estimatedRate=$null;metricSamples=(New-Object Collections.ArrayList);nextInsight=0.0}
        $script:lastJob=$job.directory; $controls.Status.Text=switch ($Action) {'Chat' {'Responding...'} 'Load' {'Loading model...'} default {'Connecting...'}}
        if ($Action -eq 'Load') { $script:loadedModel=$null; $script:loadedSelection=''; $controls.LoadProgress.Visibility='Visible'; $controls.LoadProgress.IsIndeterminate=$true }
        Set-Busy $true; Update-ChatInsights
    } catch {
        if ($Action -eq 'Chat') {
            $session.messages.RemoveAt($session.messages.Count-1); $session.transcript=$priorTranscript; $session.metrics=$priorMetrics
            $session.bubbles.RemoveAt($session.bubbles.Count-1); $session.bubbles.RemoveAt($session.bubbles.Count-1)
            $controls.Input.Text=$submitted; Show-ChatBubbles; Save-Sessions
        }
        $controls.Status.Text=$_.Exception.Message; Update-ActionControls
    }
}
$controls.Connect.Add_Click({ Start-JobAction 'Health' })
$controls.Load.Add_Click({ Start-JobAction 'Load' })
$controls.Send.Add_Click({ Start-JobAction 'Chat' })
$controls.Stop.Add_Click({ if ($script:active) { Stop-PhiBackendJob $script:active.dir; $script:active.stopRequested=$true; $controls.Status.Text='Stopping response...'; Update-ActionControls } })
$controls.Restore.Add_Click({ $script:loadedModel=$null; $script:loadedSelection=''; Start-JobAction 'InstallModern' })
$controls.New.Add_Click({ Reset-ChatConversation })
$controls.Recent.Add_SelectionChanged({ if (!$script:updatingRecent -and $controls.Recent.SelectedItem) { Select-Conversation $controls.Recent.SelectedItem } })
$controls.Recent.AddHandler([Windows.Controls.Button]::ClickEvent,[Windows.RoutedEventHandler]{ param($sender,$e)
    $button=$e.OriginalSource
    if ($button -isnot [Windows.Controls.Button] -or $button.Tag -cne 'ChatMenu') { return }
    $e.Handled=$true
    $menu=New-Object Windows.Controls.ContextMenu
    $menu.Background='#303030'; $menu.Foreground='#ECECEC'
    $rename=New-Object Windows.Controls.MenuItem; $rename.Header='Rename'; $rename.Tag=$button.DataContext.id
    $rename.Add_Click({ param($item,$event) if ($script:sessions.ContainsKey($item.Tag)) { Rename-Conversation $script:sessions[$item.Tag] } })
    $delete=New-Object Windows.Controls.MenuItem; $delete.Header='Delete chat'; $delete.Foreground='#F2A5A5'; $delete.Tag=$button.DataContext.id
    $delete.Add_Click({ param($item,$event) if ($script:sessions.ContainsKey($item.Tag)) { Remove-Conversation $script:sessions[$item.Tag] } })
    $null=$menu.Items.Add($rename); $null=$menu.Items.Add($delete)
    $menu.PlacementTarget=$button; $menu.Placement='Bottom'; $button.ContextMenu=$menu; $menu.IsOpen=$true
},$true)
$controls.Statistics.Add_Click({
    $controls.StatisticsPanel.Visibility=if ($controls.StatisticsPanel.Visibility -eq 'Visible') {'Collapsed'} else {'Visible'}
    $controls.Statistics.Content=if ($controls.StatisticsPanel.Visibility -eq 'Visible') {'Hide statistics'} else {'Statistics'}
    Update-ChatInsights
})
$controls.ContextUsage.Add_Click({ $controls.StatisticsPanel.Visibility='Visible'; $controls.Statistics.Content='Hide statistics'; Update-ChatInsights })
$controls.Model.Add_SelectionChanged({
    if ($script:updatingModels -or !$controls.Model.SelectedItem) { return }
    if (!$script:conversation.locked) { $script:selectedModel=$controls.Model.SelectedItem.name; $script:conversation.model=$script:selectedModel; $script:dirty=$true; Show-SelectedModelState; Update-ForecastPreview; Update-ChatInsights }
})
$controls.Input.Add_TextChanged({ if (!$script:switching) { $script:dirty=$true }; Update-ActionControls })
$controls.Input.Add_PreviewKeyDown({ param($sender,$e)
    if ($e.Key -eq 'Return' -and !([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift)) { $e.Handled=$true; Start-JobAction 'Chat' }
})
$controls.Save.Add_Click({
    $dialog=New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter='Text files (*.txt)|*.txt'; $dialog.FileName='phi-chat-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.txt'
    if ($dialog.ShowDialog($window)) { Write-Utf8 $dialog.FileName $script:conversation.transcript }
})
$controls.Evidence.Add_Click({ $dir=if ($script:lastJob) {$script:lastJob} else {$connection.data_dir}; $null=Start-Process explorer.exe -ArgumentList (Join-NativeArguments @($dir)) })
$timer=New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(100)
function Update-ChatJobs {
    try {
        if ($script:dirty -and ([DateTime]::UtcNow-$script:lastSave).TotalSeconds -ge 1) { Save-Sessions }
        if ($script:probe -and $script:probe.process.HasExited) {
            $probe=$script:probe; $script:probe=$null
            try {
                $status=Read-JsonFile (Join-Path $probe.directory 'status.json')
                if ($status.state -ceq 'done') { Accept-CardSession $status.result }
                elseif ($status.PSObject.Properties['card_offline'] -and $status.card_offline) { Clear-CardSessions; $controls.ConnectionState.Text='Card offline'; $controls.Status.Text='Card offline. Recent chats cleared.' }
                else { $controls.ConnectionState.Text='Connection unavailable'; $controls.Status.Text=$status.message; $script:connectedSerial=''; Update-ActionControls }
            } finally { $probe.process.Dispose(); $script:nextProbe=[DateTime]::UtcNow.AddSeconds(20) }
        }
        if (!$script:active) {
            if (!$script:probe -and [DateTime]::UtcNow -ge $script:nextProbe) {
                $request=[pscustomobject]@{action='Probe';batch=0;owner_pid=$PID}
                $script:probe=Start-PhiBackendJob $PSScriptRoot $connection.data_dir $request
                Update-ActionControls
                $script:nextProbe=[DateTime]::UtcNow.AddSeconds(20)
            }
            return
        }
        $a=$script:active; $status=$null; $path=Join-Path $a.dir 'status.json'
        if (Test-Path -LiteralPath $path) { try { $status=Read-JsonFile $path } catch {} }
        $complete=$a.process.HasExited
        if ($complete -and $a.process.ExitCode -ne 0 -and (Test-Path -LiteralPath (Join-Path $a.dir 'failure.json'))) { $status=Read-JsonFile (Join-Path $a.dir 'failure.json') }
        if ($status) {
            if ($status.PSObject.Properties['temperature_c']) { $controls.ThermalStatus.Text=('{0} C | stop at {1} C' -f $status.temperature_c,$status.thermal_stop_c) }
            if ($status.PSObject.Properties['memory'] -and $status.memory) { $script:lastMemorySnapshot=$status.memory.snapshot; $controls.MemoryStatus.Text=('{0:N0} MiB available' -f ($status.memory.snapshot.available_kib/1024)) }
            if ($a.action -eq 'Load') {
                $controls.LoadStatus.Text=$status.message; $controls.Status.Text=$status.message
                $controls.LoadProgress.IsIndeterminate=($null -eq $status.progress -and !$complete)
                if ($status.progress) { $controls.LoadProgress.Value=$status.progress.percent }
            }
        }
        if ($a.action -ceq 'Chat') {
            $piece=$a.tail.Read((Join-Path $a.dir 'response.txt'),$complete)
            if ($piece.Length) { $null=$a.answer.Append($piece); Update-ChatBubble $a.answer.ToString(); $script:dirty=$true }
            $a.estimatedRate=$a.rate.Add($piece,$a.watch.Elapsed.TotalSeconds)
            if ($complete -or $a.watch.Elapsed.TotalSeconds -ge $a.nextInsight) {
                Update-JobInsights $a $status $complete; Update-ChatInsights; $script:dirty=$true
                $a.nextInsight=$a.watch.Elapsed.TotalSeconds+0.5
            }
        }
        if (!$complete) { return }
        if ($a.action -eq 'Load' -and $a.process.ExitCode -eq 0 -and $status -and $status.state -ceq 'done') {
            $script:loadedModel=$status.result; $script:loadedSelection=$a.model; $controls.Status.Text='Ready'; $controls.LoadProgress.Visibility='Collapsed'
        } elseif ($a.action -eq 'Chat') {
            $text=$a.answer.ToString()
            if ($status -and $status.state -ceq 'done' -and $a.process.ExitCode -eq 0) { Complete-ChatTurn $a.conversation $a.bubble $text 'done'; $controls.Status.Text=''; }
            elseif ($status -and $status.state -ceq 'cancelled' -and $status.preserve_ready) { Complete-ChatTurn $a.conversation $a.bubble $text 'stopped'; $controls.Status.Text='Response stopped'; }
            else {
                $a.bubble.state='failed'; $a.bubble.text=$text
                $a.conversation.messages.RemoveAt($a.conversation.messages.Count-1); $a.conversation.transcript=$a.priorTranscript
                $a.conversation.draft=$a.conversation.bubbles[$a.conversation.bubbles.Count-2].text
                if ($script:conversation.id -ceq $a.conversation.id -and !$controls.Input.Text) { $controls.Input.Text=$a.conversation.draft }
                if (!(Test-RecoverableChatFailure $status)) { $script:loadedModel=$null; $script:loadedSelection='' }
                $controls.Status.Text=if ($status) {$status.message} else {'Worker stopped. Open evidence for details.'}
            }
            if ($script:conversation.id -ceq $a.conversation.id) { Show-ChatBubbles; $controls.Transcript.Text=$a.conversation.transcript }
            Update-RecentChats; Save-Sessions
        } elseif ($a.process.ExitCode -ne 0) {
            $controls.Status.Text=if ($status) {$status.message} else {'Connection failed'}
            $script:loadedModel=$null; $script:loadedSelection=''
        } else { $controls.Status.Text='Connected'; $script:nextProbe=[DateTime]::MinValue }
        Remove-Item -LiteralPath (Join-Path $a.dir 'response.txt') -Force -ErrorAction SilentlyContinue
        $a.process.Dispose(); $script:active=$null; Set-Busy $false; Show-SelectedModelState; Update-ForecastPreview; Update-ChatInsights
    } catch { $controls.Status.Text=$_.Exception.Message; $script:nextProbe=[DateTime]::UtcNow.AddSeconds(20) }
}
$timer.Add_Tick({ Update-ChatJobs })
$window.Add_Closing({
    try { Save-Sessions } catch {}
    if ($script:active) { Stop-PhiBackendJob $script:active.dir }
    if ($script:probe) { Stop-PhiBackendJob $script:probe.directory }
    $timer.Stop()
})
Update-RecentChats
Update-ActionControls
Update-ChatInsights
$timer.Start()
[void]$window.ShowDialog()
