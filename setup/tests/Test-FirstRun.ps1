#Requires -Version 5.1
# Exercise the complete first-boot provisioning function against an MPSS fixture.
# All system/network/card commands are replaced before the function is invoked.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'setup/lib/HostSetup.ps1')
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('phi-first-run-'+[Guid]::NewGuid().ToString('N'))
New-Directory $scratch
$script:checks=0
function Check([bool]$Value,[string]$Message) { $script:checks++; if (!$Value) { throw ('FAIL: '+$Message) } }
try {
    $mpss=Join-Path $scratch 'MPSS'; $install=Join-Path $scratch 'fresh user/PhiChat'
    foreach ($name in @('bin','filesystem/mic0','filesystem/common')) { New-Directory (Join-Path $mpss $name) }
    foreach ($name in @('bin/micctrl.exe','bin/MicInfo.exe')) { Write-Utf8 (Join-Path $mpss $name) 'fixture marker, never executed' }
    Write-Utf8 (Join-Path $mpss 'global.xml') '<global />'
    Write-Utf8 (Join-Path $mpss 'mic0.xml') '<mic0><Networking><IPAddress>192.168.66.2</IPAddress><HostIPAddress>192.168.66.1</HostIPAddress><Subnet>255.255.255.0</Subnet><HostSubnet>255.255.255.0</HostSubnet></Networking></mic0>'
    Write-Utf8 (Join-Path $mpss 'filesystem/mic0.filelist') "# existing MPSS entries`nfile /etc/hostname etc/hostname 644 0 0`n"
    Write-Utf8 (Join-Path $mpss 'filesystem/common.filelist') ''
    # Intentionally no preexisting boot image, SSH keys, config or acceptance.
    $null=Copy-PhiApplication $root $install
    $run=Get-PhiSetupRun $install
    $adapter=[pscustomobject]@{ifIndex=7;InterfaceDescription='Xeon Phi Virtual Ethernet'}
    $plan=New-PhiNetworkPlan $mpss $adapter @() @()
    $plan | Add-Member device_id 'fixture'; $plan | Add-Member install_openssh $false
    $script:fakeState='ready'; $script:generated=0; $script:boots=0; $script:resets=0; $script:sshCalls=0
    $script:realProcess=(Get-Item Function:Invoke-SetupProcess).ScriptBlock
    function Enable-PhiTools { param($Plan) }
    function Start-PhiServices { param($Mpss,$Run) }
    function Get-PhiHostPlan { param($MpssDirectory,$InterfaceIndex); return $plan }
    function Get-NetIPInterface { param($InterfaceIndex,$AddressFamily); [pscustomobject]@{Dhcp='Disabled'} }
    function New-NetIPAddress { param($InterfaceIndex,$IPAddress,$PrefixLength,$ErrorAction); Check ($InterfaceIndex -eq 7 -and $IPAddress -ceq '192.168.66.1') 'provisions the planned Phi address' }
    function Invoke-SetupProcess {
        param($Exe,$Arguments,$Run,$Timeout=15000)
        if ($Exe -ceq (Join-Path $mpss 'bin/micctrl.exe')) {
            switch ($Arguments[0]) {
                '-s' { return ('mic0: '+$script:fakeState) }
                '-g' { $script:generated++; Write-Utf8 (Join-Path $mpss 'filesystem/mic0.image') ('fixture image '+$script:generated); return '' }
                '-b' { $script:boots++; $script:fakeState='online'; return '' }
                '-r' { $script:resets++; $script:fakeState='ready'; return '' }
                default { throw 'Unexpected fixture micctrl operation.' }
            }
        }
        if ((Split-Path $Exe -Leaf) -ceq 'ssh.exe') {
            $script:sshCalls++
            Check ('StrictHostKeyChecking=yes' -cin $Arguments -and 'GlobalKnownHostsFile=NUL' -cin $Arguments) 'first SSH uses pinned private host trust'
            $marker=Read-SmallText (Join-Path $mpss 'filesystem/mic0/phi-chat-identity/receipt.txt')
            return ("k1om`n"+$marker.Trim()+"`n00000000-0000-0000-0000-000000000001`n")
        }
        if ((Split-Path $Exe -Leaf) -cne 'ssh-keygen.exe') { throw 'Fixture refused unexpected host executable.' }
        return (& $script:realProcess $Exe $Arguments $Run $Timeout)
    }
    $result=Initialize-PhiHost $install $plan $run
    Check ($script:generated -eq 2 -and $script:boots -eq 1 -and $script:resets -eq 0) 'fresh MPSS image generated, then provisioned and booted once'
    Check ($script:sshCalls -eq 1 -and $result.boot_id -ceq '00000000-0000-0000-0000-000000000001') 'host receipt follows verified boot identity'
    Check (Test-Path -LiteralPath (Join-Path $install 'app/private/id_ed25519')) 'new user receives a login identity'
    Check (Test-Path -LiteralPath (Join-Path $install 'app/config/connection.yaml')) 'connection is generated locally'
    Check (!(Test-Path -LiteralPath (Join-Path $install 'app/data/modern-runtime'))) 'boot provisioning cannot fabricate runtime acceptance'
    $pending=Read-Json (Join-Path $install 'data/host/pending.json')
    $journal=Read-Json (Join-Path $pending.plan_directory 'journal.json')
    Check ($journal.state -ceq 'image-generated' -and (Test-Path -LiteralPath (Join-Path $pending.plan_directory 'before'))) 'boot transaction and original image backup are retained'
    Check ((Read-SmallText (Join-Path $mpss 'filesystem/mic0.filelist')).Contains('file /etc/hostname etc/hostname 644 0 0')) 'unrelated MPSS configuration survives first run'
    Write-Output ('PASS: '+$script:checks+' complete first-run fixture checks; no real MPSS, network or card commands executed.')
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^phi-first-run-[a-f0-9]{32}$') { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
