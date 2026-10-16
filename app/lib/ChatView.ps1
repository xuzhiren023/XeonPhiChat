# WPF rendering only. Reasoning is model-emitted text, always rendered as text.
function Show-ChatRenameDialog([string]$Title) {
    [xml]$markup=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Rename chat" Width="410" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner" Background="#212121" Foreground="#ECECEC" FontFamily="Segoe UI" ShowInTaskbar="False">
 <StackPanel Margin="24"><TextBlock Text="Rename chat" FontSize="19" Margin="0,0,0,18"/><TextBox x:Name="ChatName" MaxLength="80" FontSize="15" Padding="10" Background="#303030" Foreground="#ECECEC" BorderBrush="#555555"/><StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0"><Button Content="Cancel" IsCancel="True" Padding="16,8" Margin="0,0,8,0"/><Button x:Name="Accept" Content="Save" IsDefault="True" Padding="16,8"/></StackPanel></StackPanel>
</Window>
'@
    $dialog=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader($markup)))
    $dialog.Owner=$window; $dialog.Resources=$window.Resources
    $nameBox=$dialog.FindName('ChatName'); $saveButton=$dialog.FindName('Accept')
    $nameBox.Text=$Title
    $nameBox.Add_TextChanged({ $saveButton.IsEnabled=![string]::IsNullOrWhiteSpace($nameBox.Text) }.GetNewClosure())
    $saveButton.Add_Click({ $dialog.DialogResult=$true }.GetNewClosure())
    $dialog.Add_ContentRendered({ $nameBox.Focus() | Out-Null; $nameBox.SelectAll() }.GetNewClosure())
    if ($dialog.ShowDialog()) { return $nameBox.Text }
    return $null
}
function Confirm-ChatDeletion([string]$Title) {
    return ([Windows.MessageBox]::Show($window,('Delete "'+$Title+'"? This removes its conversation history. An active response in this chat will be stopped.'),'Delete chat','YesNo','Question','No') -eq 'Yes')
}
function New-MessageText([string]$Text,[string]$Color='#ECECEC') {
    $body=New-Object Windows.Controls.TextBox
    $body.Text=$Text; $body.IsReadOnly=$true; $body.TextWrapping='Wrap'; $body.FontSize=15
    $body.Background='Transparent'; $body.Foreground=$Color; $body.BorderThickness=New-Object Windows.Thickness(0)
    $body.Padding=New-Object Windows.Thickness(0); $body.IsReadOnlyCaretVisible=$false
    return $body
}
function Add-ChatBubble([string]$Role,[string]$Text,[object[]]$Images=@()) {
    $item=[pscustomobject]@{role=$Role;text=$Text;images=$Images;state=$(if ($Role -ceq 'assistant') {'streaming'} else {'done'});starts_thinking=(Test-PromptStartsThinking (Get-ModelProfile $script:appRoot $script:selectedModel))}
    $null=$script:conversation.bubbles.Add($item)
    $script:liveBubble=Render-ChatBubble $item
    return $item
}
function Render-ChatBubble($Item) {
    $user=($Item.role -ceq 'user')
    $border=New-Object Windows.Controls.Border
    $border.Background=if ($user) { '#303030' } else { 'Transparent' }
    $border.CornerRadius=New-Object Windows.CornerRadius(20)
    $border.Padding=New-Object Windows.Thickness(18,12,18,12)
    $border.Margin=New-Object Windows.Thickness(8,10,8,16)
    $border.HorizontalAlignment=if ($user) { 'Right' } else { 'Stretch' }
    $border.MaxWidth=if ($user) { 600 } else { 780 }
    $panel=New-Object Windows.Controls.StackPanel
    if ($user -and @(Get-MessageImages $Item).Count) {
        $pictures=New-Object Windows.Controls.WrapPanel
        foreach ($picture in @(Get-MessageImages $Item)) {
            $thumb=New-ImageThumbnail $picture 180; $thumb.Margin=New-Object Windows.Thickness(0,0,8,10)
            $null=$pictures.Children.Add($thumb)
        }
        $null=$panel.Children.Add($pictures)
    }
    $body=New-MessageText $Item.text
    $reason=New-MessageText '' '#AAAAAA'
    $reason.FontSize=13; $reason.Margin=New-Object Windows.Thickness(12,8,0,14)
    $expander=New-Object Windows.Controls.Expander
    $expander.Foreground='#AAAAAA'; $expander.Content=$reason; $expander.Header='Thinking'; $expander.Visibility='Collapsed'
    $note=New-Object Windows.Controls.TextBlock
    $note.Foreground='#999999'; $note.FontSize=12; $note.Margin=New-Object Windows.Thickness(0,8,0,0)
    if (!$user) { $null=$panel.Children.Add($expander) }
    $null=$panel.Children.Add($body); $null=$panel.Children.Add($note); $border.Child=$panel
    $null=$controls.ChatMessages.Children.Add($border)
    $view=[pscustomobject]@{item=$Item;body=$body;reason=$reason;expander=$expander;note=$note}
    if (!$user) { Set-AssistantView $view }
    return $view
}
function Set-AssistantView($View) {
    $item=$View.item; $complete=($item.state -cne 'streaming')
    $parts=Split-AssistantContent $item.text $item.starts_thinking $complete
    $View.body.Text=$parts.answer
    $View.body.Visibility=if ($parts.answer) {'Visible'} else {'Collapsed'}
    $View.reason.Text=$parts.reasoning
    $View.expander.Visibility=if ($parts.reasoning -or $parts.thinking) {'Visible'} else {'Collapsed'}
    $View.expander.Header=if ($parts.thinking) {'Thinking...'} elseif ($item.state -in @('stopped','interrupted')) {'Thinking interrupted'} else {'Thought process'}
    $View.note.Text=switch ($item.state) { 'stopped' {'Response stopped'} 'interrupted' {'Response interrupted'} 'failed' {'Response failed'} default { if (!$complete -and !$parts.answer -and !$parts.thinking) {'Responding...'} else {''} } }
    if ($parts.thinking) {
        $animation=New-Object Windows.Media.Animation.DoubleAnimation
        $animation.From=0.45; $animation.To=1.0; $animation.Duration=New-Object Windows.Duration([TimeSpan]::FromSeconds(1))
        $animation.AutoReverse=$true; $animation.RepeatBehavior=[Windows.Media.Animation.RepeatBehavior]::Forever
        if (!$View.expander.HasAnimatedProperties) { $View.expander.BeginAnimation([Windows.UIElement]::OpacityProperty,$animation) }
    } else { $View.expander.BeginAnimation([Windows.UIElement]::OpacityProperty,$null) }
}
function Show-ChatBubbles {
    $controls.ChatMessages.Children.Clear(); $script:liveBubble=$null
    foreach ($item in $script:conversation.bubbles) {
        $view=Render-ChatBubble $item
        if ($script:active -and $script:active.action -ceq 'Chat' -and [object]::ReferenceEquals($item,$script:active.bubble)) { $script:liveBubble=$view }
    }
    $controls.Welcome.Visibility=if ($script:conversation.bubbles.Count) {'Collapsed'} else {'Visible'}
    $controls.ChatScroll.ScrollToEnd()
}
function Update-ChatBubble([string]$Text) {
    if (!$script:active -or $script:active.action -cne 'Chat') { return }
    $script:active.bubble.text=$Text
    if ($script:conversation.id -ceq $script:active.conversation.id -and $script:liveBubble) {
        $follow=($controls.ChatScroll.ScrollableHeight-$controls.ChatScroll.VerticalOffset -lt 80)
        Set-AssistantView $script:liveBubble
        if ($follow) { $controls.ChatScroll.ScrollToEnd() }
    }
}
function Update-ForecastPreview {
    if (!(Test-SelectedReady) -or !$script:loadedModel.PSObject.Properties['resources']) { $controls.Forecast.Text='Automatic resources'; return }
    $r=$script:loadedModel.resources
    $controls.Forecast.Text=('{0:N0} context | batch {1} | reply uses remaining context' -f $r.context_tokens,$r.batch_tokens)
}
