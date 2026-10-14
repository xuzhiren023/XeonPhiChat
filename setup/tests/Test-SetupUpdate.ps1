#Requires -Version 5.1
param([string]$InstallerRoot='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (!$InstallerRoot) { $InstallerRoot=$root }
. (Join-Path $root 'setup/lib/HostSetup.ps1')
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('phi-update-'+[Guid]::NewGuid().ToString('N'))
New-Directory $scratch
$checks=0
function Check([bool]$Value,[string]$Message) { $script:checks++; if (!$Value) { throw ('FAIL: '+$Message) } }
try {
    $fixture=Join-Path $scratch 'extracted Windows installer'
    $null=Copy-PhiApplication $InstallerRoot $fixture
    Remove-Item -LiteralPath (Join-Path $fixture 'installation.json')
    # Use tiny pinned dependencies. The release builder separately verifies
    # every byte of the real Windows ZIP, including the large projector.
    $manifest=Read-PhiAssetManifest $fixture
    New-Directory (Join-Path $fixture 'assets/payloads')
    foreach ($asset in $manifest.assets) {
        $path=Join-Path $fixture ('assets/payloads/'+$asset.file)
        Write-Utf8 $path ('fixture '+$asset.file+('x'*2048))
        $asset.bytes=(Get-Item -LiteralPath $path).Length
        $asset.sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()
    }
    Save-Json (Join-Path $fixture 'assets/runtime-manifest.json') $manifest
    Add-Content -LiteralPath (Join-Path $fixture 'setup/lib/HostSetup.ps1') -Value @'
function Test-PhiAdministrator { throw 'Unexpected elevation check during an app update' }
function Get-PhiHostPlan { throw 'Unexpected hardware query during an app update' }
function Initialize-PhiHost { throw 'Unexpected host provisioning during an app update' }
function Invoke-PhiSetupJob { throw 'Unexpected card job during an app update' }
function Start-PhiServices { throw 'Unexpected service operation during an app update' }
function New-PhiShortcut { param($Destination); Write-Utf8 (Join-Path $Destination 'shortcut-fixture.txt') 'created' }
'@
    $local=Join-Path $scratch 'local user'
    $old=Join-Path $local 'Programs/PhiChat/1.6.5'
    $version=Get-PhiVersion $fixture
    $target=Join-Path $local ('Programs/PhiChat/'+$version)
    Check ($version -cne '1.6.5') 'update fixture starts from the reported version'
    $receipt=Copy-PhiApplication $fixture $old
    Write-Utf8 (Join-Path $old 'VERSION') '1.6.5'
    $receipt.version='1.6.5'; $receipt.status='installed'
    Save-Json (Join-Path $old 'installation.json') $receipt
    foreach ($folder in @('app/private','data/host/data','app/data/modern-runtime')) { New-Directory (Join-Path $old $folder) }
    foreach ($name in @('id_ed25519','id_ed25519.pub','known_hosts')) { Write-Utf8 (Join-Path $old ('app/private/'+$name)) ('fixture '+$name) }
    Save-Json (Join-Path $old 'app/config/connection.yaml') ([pscustomobject]@{schema_version=3;portable=$true;system_dependencies=$true;project_dir='.';phase3_kit='dependencies/phase3';data_dir='data';key_path='private/id_ed25519';known_hosts='private/known_hosts';card_address='192.168.1.100'})
    Save-Json (Join-Path $old 'data/host/data/settings.yaml') ([pscustomobject]@{mpss_dir='fixture MPSS, never accessed'})
    Write-Utf8 (Join-Path $old 'app/data/modern-runtime/active-FIXTURE.json') '{"validation":"original acceptance fixture"}'
    Write-Utf8 (Join-Path $old 'keep.txt') 'user file'
    function Run-Setup([int]$ExpectedExit=0) {
        $info=New-Object Diagnostics.ProcessStartInfo
        $info.FileName=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
        $info.Arguments=Join-NativeArguments @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $fixture 'Setup.ps1'),'-NoLaunch')
        $info.UseShellExecute=$false; $info.CreateNoWindow=$true
        $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
        $info.EnvironmentVariables['LOCALAPPDATA']=$local
        $process=New-Object Diagnostics.Process; $process.StartInfo=$info
        try {
            $null=$process.Start()
            $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
            if (!$process.WaitForExit(45000)) { $process.Kill(); throw 'Setup update fixture timed out' }
            $output=$stdout.Result+$stderr.Result
            if ($process.ExitCode -ne $ExpectedExit) { throw ('Unexpected Setup.ps1 result: '+$output) }
            return $output
        } finally { $process.Dispose() }
    }
    $null=Run-Setup
    $installed=Read-Json (Join-Path $target 'installation.json')
    Check ($installed.status -ceq 'installed' -and $installed.upgrade_source -ceq $old) 'actual installer entry upgrades before UAC, queries, or card jobs'
    foreach ($name in @('app/private/id_ed25519','app/private/known_hosts','app/config/connection.yaml','app/data/modern-runtime/active-FIXTURE.json')) {
        Check ((Get-FileHash -LiteralPath (Join-Path $old $name)).Hash -ceq (Get-FileHash -LiteralPath (Join-Path $target $name)).Hash) ('saved bytes reused: '+$name)
    }
    Check ((Read-SmallText (Join-Path $old 'keep.txt')) -ceq 'user file') 'previous installation and unknown files preserved'
    Check (!(Test-Path -LiteralPath (Join-Path $target 'data/host/verified.json'))) 'update does not fabricate a boot validation receipt'
    $legacy=Join-Path $target 'app/Test-ModernRuntime.ps1'; Write-Utf8 $legacy '# legacy developer file'
    $installed.source_files+=@([pscustomobject]@{path='app/Test-ModernRuntime.ps1';sha256=(Get-FileHash -LiteralPath $legacy).Hash.ToLowerInvariant()})
    Save-Json (Join-Path $target 'installation.json') $installed
    $null=Run-Setup
    Check ((Read-Json (Join-Path $target 'installation.json')).installed_utc -ceq $installed.installed_utc) 'same-version retry with legacy developer entry completes without provisioning or revalidation'
    # A dependency failure after source copy must resume as an update.
    $installed.status='copied'; Save-Json (Join-Path $target 'installation.json') $installed
    $null=Run-Setup
    Check ((Read-Json (Join-Path $target 'installation.json')).status -ceq 'installed') 'interrupted update resumes using its recorded source'
    Add-Content -LiteralPath (Join-Path $target 'Start.ps1') '# user change'
    $failure=Run-Setup 1
    Check ($failure.Contains('Installed or source code changed')) 'retry preserves edited production code'
    Write-Output ('PASS: '+$checks+' installer update checks; real Setup.ps1, hardware and elevation calls forbidden.')
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^phi-update-[a-f0-9]{32}$') { throw 'Unsafe update test cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
