function New-ImageThumbnail($Image,[int]$Size=80) {
    $view=New-Object Windows.Controls.Image
    $view.Width=$Size; $view.Height=$Size; $view.Stretch='UniformToFill'; $view.ToolTip=$Image.name
    try { $view.Source=Read-ChatImage (Get-ImagePath $connection.data_dir $Image) ($Size*2) } catch { $view.ToolTip='Image unavailable: '+$Image.name }
    $view.Tag=$Image
    $view.Add_MouseLeftButtonUp({ param($sender,$event)
        try {
            $preview=New-Object Windows.Window
            $preview.Title=$sender.Tag.name; $preview.Owner=$window; $preview.Width=800; $preview.Height=650
            $preview.Background='#171717'; $preview.WindowStartupLocation='CenterOwner'
            $large=New-Object Windows.Controls.Image; $large.Stretch='Uniform'; $large.Margin=New-Object Windows.Thickness(16)
            $large.Source=Read-ChatImage (Get-ImagePath $connection.data_dir $sender.Tag)
            $preview.Content=$large; $null=$preview.ShowDialog()
        } catch { Show-Problem $_.Exception.Message }
        $event.Handled=$true
    })
    return $view
}
function Show-Attachments {
    $controls.Attachments.Children.Clear()
    foreach ($image in @($script:conversation.images)) {
        $tile=New-Object Windows.Controls.Grid; $tile.Margin=New-Object Windows.Thickness(0,0,10,8)
        $border=New-Object Windows.Controls.Border; $border.CornerRadius=New-Object Windows.CornerRadius(12)
        $border.ClipToBounds=$true; $border.Child=New-ImageThumbnail $image
        $null=$tile.Children.Add($border)
        $remove=New-Object Windows.Controls.Button; $remove.Content=[char]0x00D7; $remove.Tag=$image.id
        $remove.Width=22; $remove.Height=22; $remove.Padding=New-Object Windows.Thickness(0)
        $remove.HorizontalAlignment='Right'; $remove.VerticalAlignment='Top'; $remove.ToolTip='Remove image'
        $remove.Add_Click({param($sender,$event)
            $script:conversation.images=@($script:conversation.images | Where-Object id -CNE $sender.Tag)
            Show-Attachments; Update-ActionControls; $script:dirty=$true
        })
        $null=$tile.Children.Add($remove); $null=$controls.Attachments.Children.Add($tile)
    }
    $controls.Attachments.Visibility=if ($script:conversation.images.Count) {'Visible'} else {'Collapsed'}
}
function Add-ImageFiles([string[]]$Paths) {
    try {
        $model=Get-ModelProfile $script:appRoot $script:selectedModel
        if (!(Test-ImageModel $model)) { throw 'Choose LFM2.5-VL or Step3-VL in a new chat to attach images.' }
        if ($script:active) { throw 'Wait for the response to finish before attaching an image.' }
        if ($script:conversation.images.Count+$Paths.Count -gt 4) { throw 'This runtime accepts up to four images in a prompt.' }
        foreach ($path in $Paths) { $script:conversation.images+=@(Import-ChatImage $connection.data_dir $path) }
    } catch { Show-Problem $_.Exception.Message }
    finally { Show-Attachments; Update-ActionControls; $script:dirty=$true }
}
function Initialize-ImageControls {
    $controls.Attach.Add_Click({
        $picker=New-Object Microsoft.Win32.OpenFileDialog
        $picker.Title='Attach images'; $picker.Filter='Images (*.png;*.jpg;*.jpeg;*.bmp)|*.png;*.jpg;*.jpeg;*.bmp'; $picker.Multiselect=$true
        if ($picker.ShowDialog($window)) { Add-ImageFiles @($picker.FileNames) }
    })
    $window.AllowDrop=$true
    $window.Add_PreviewDragOver({param($sender,$e)
        if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
            $e.Handled=$true; $e.Effects='None'
            if ($controls.Attach.IsEnabled) { $e.Effects='Copy'; $controls.DropOverlay.Visibility='Visible' }
        }
    })
    $window.Add_PreviewDragLeave({param($sender,$e) $controls.DropOverlay.Visibility='Collapsed'})
    $window.Add_PreviewDrop({param($sender,$e)
        $controls.DropOverlay.Visibility='Collapsed'
        if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
            $e.Handled=$true; Add-ImageFiles @($e.Data.GetData([Windows.DataFormats]::FileDrop))
        }
    })
}
