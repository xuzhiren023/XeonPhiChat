#Requires -Version 5.1
# Local application updates do not provision, probe, or restart the card.
function Test-PhiInstalledConfiguration([string]$Path) {
    if (!(Test-Path -LiteralPath (Join-Path $Path 'installation.json') -PathType Leaf)) { return $false }
    $receipt=Read-Json (Join-Path $Path 'installation.json')
    if ($receipt.product -cne 'PhiChat' -or $receipt.status -cne 'installed') { return $false }
    foreach ($relative in @('app/config/connection.yaml','app/private/id_ed25519','app/private/id_ed25519.pub','app/private/known_hosts','data/host/data/settings.yaml')) {
        if (!(Test-Path -LiteralPath (Join-Safe $Path $relative) -PathType Leaf)) { return $false }
    }
    $connection=Read-Json (Join-Path $Path 'app/config/connection.yaml')
    # Only the portable layout can be copied without retaining old app paths.
    foreach ($entry in @(@('key_path','private/id_ed25519'),@('known_hosts','private/known_hosts'),@('data_dir','data'),@('project_dir','.'),@('phase3_kit','dependencies/phase3'))) {
        if (!$connection.PSObject.Properties[$entry[0]] -or $connection.($entry[0]) -cne $entry[1]) { return $false }
    }
    return $true
}
function Find-PhiPreviousInstallation([string]$Root,[string]$Destination) {
    $parents=@((Split-Path $Destination -Parent),(Join-Path $env:LOCALAPPDATA 'Programs/PhiChat')) | Select-Object -Unique
    $candidates=@(foreach ($parent in $parents) {
        if (!(Test-Path -LiteralPath $parent -PathType Container)) { continue }
        foreach ($directory in @(Get-ChildItem -LiteralPath $parent -Directory)) {
            if ($directory.Name -notmatch '^\d+\.\d+\.\d+$' -or [version]$directory.Name -ge [version](Get-PhiVersion $Root)) { continue }
            $directory
        }
    })
    foreach ($previous in @($candidates | Sort-Object { [version]$_.Name } -Descending)) {
        if (Test-PhiInstalledConfiguration $previous.FullName) { return $previous.FullName }
    }
    return ''
}
function Copy-PhiSavedFile([string]$Previous,[string]$Destination,[string]$Relative) {
    $source=Join-Safe $Previous $Relative; $target=Join-Safe $Destination $Relative
    Assert-RegularPath $source; Assert-RegularPath $target
    if (!(Test-Path -LiteralPath $source -PathType Leaf)) { return }
    New-Directory (Split-Path $target -Parent)
    if (Test-Path -LiteralPath $target) {
        if ((Get-FileHash -LiteralPath $source).Hash -cne (Get-FileHash -LiteralPath $target).Hash) { throw ('Saved configuration differs: '+$Relative+'. Existing files are preserved.') }
    } else { Copy-Item -LiteralPath $source -Destination $target }
    if ($Relative.StartsWith('app/private/')) { Protect-IdentityFile $target }
}
function Invoke-PhiApplicationUpdate([string]$Root,[string]$Destination,[string]$AssetsDirectory,[string]$ModelPackDirectory) {
    $receiptPath=Join-Path $Destination 'installation.json'
    $previous=''
    if (Test-Path -LiteralPath $receiptPath) {
        $saved=Read-Json $receiptPath
        if ($saved.product -cne 'PhiChat' -or $saved.version -cne (Get-PhiVersion $Root)) { throw 'Use a new folder for this app version. Existing installation preserved.' }
        if ($saved.status -ceq 'installed') {
            if (!(Test-PhiInstalledConfiguration $Destination)) { throw 'Saved connection files are incomplete. Restore them from the previous installation; setup will not replace the card identity.' }
            if ((Resolve-Absolute $Root) -ine (Resolve-Absolute $Destination)) { $null=Copy-PhiApplication $Root $Destination }
            if ($ModelPackDirectory) { $null=Import-PhiOptimizedModels $Root $Destination $ModelPackDirectory }
            New-PhiShortcut $Destination
            Write-Host ('Phi Chat '+$saved.version+' is already installed. Saved connection and card configuration reused.')
            return $true
        }
        if ($saved.PSObject.Properties['upgrade_source']) { $previous=[string]$saved.upgrade_source }
        else { return $false } # Resume an interrupted first-time provisioning normally.
    } else { $previous=Find-PhiPreviousInstallation $Root $Destination }
    if (!$previous) { return $false }
    Assert-RegularPath $previous
    if (!(Test-PhiInstalledConfiguration $previous)) { throw ('The previous installation is incomplete: '+$previous+'. Restore its saved connection files to resume this update.') }
    Write-Host ('Installing Phi Chat '+(Get-PhiVersion $Root)+' using the saved connection from '+$previous)
    $null=Get-PhiAssets $Root $AssetsDirectory
    $receipt=Copy-PhiApplication $Root $Destination
    # Record the update source before copying dependencies so retries cannot
    # accidentally enter first-time provisioning after an interrupted update.
    $receipt | Add-Member upgrade_source $previous -Force
    $receipt | Add-Member upgrade_from (Get-PhiVersion $previous) -Force
    Save-Json $receiptPath $receipt
    Install-PhiAssets $Root $AssetsDirectory $Destination
    $private=Join-Path $Destination 'app/private'; New-Directory $private; Protect-IdentityDirectory $private
    foreach ($relative in @('app/config/connection.yaml','app/private/id_ed25519','app/private/id_ed25519.pub','app/private/known_hosts','app/private/ssh_host_ed25519_key','app/private/ssh_host_ed25519_key.pub','data/host/data/settings.yaml','data/host/pending.json','data/host/verified.json')) {
        Copy-PhiSavedFile $previous $Destination $relative
    }
    # These remain the original native acceptance records, checked against the
    # actual card and exact package pins by the backend when the app connects.
    $selection=Join-Path $previous 'app/data/modern-runtime'
    if (Test-Path -LiteralPath $selection -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $selection -File | Where-Object Name -Match '^active-[A-Za-z0-9-]+\.json$')) {
            Copy-PhiSavedFile $previous $Destination ('app/data/modern-runtime/'+$file.Name)
        }
    }
    if ($ModelPackDirectory) { $null=Import-PhiOptimizedModels $Root $Destination $ModelPackDirectory }
    New-PhiShortcut $Destination
    $receipt.status='installed'
    $receipt | Add-Member setup_method 'Application update; saved connection reused; no hardware validation performed by setup.' -Force
    $receipt | Add-Member installed_utc ([DateTime]::UtcNow.ToString('o')) -Force
    Save-Json $receiptPath $receipt
    Write-Host 'Phi Chat is installed. Open its desktop shortcut when you are ready to use the card.'
    return $true
}
