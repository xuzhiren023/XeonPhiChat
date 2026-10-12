#Requires -Version 5.1
. (Join-Path $PSScriptRoot 'SetupCore.ps1')

function Test-PhiAdministrator {
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Find-PhiMpss([string]$Hint='') {
    $path=if ($Hint) { Resolve-Absolute $Hint } else { Join-Path $env:ProgramFiles 'Intel/MPSS' }
    Assert-RegularPath $path
    foreach ($relative in @('bin/micctrl.exe','bin/MicInfo.exe','mic0.xml','global.xml','filesystem/mic0.filelist')) {
        if (!(Test-Path -LiteralPath (Join-Safe $path $relative) -PathType Leaf)) {
            throw "The full Intel MPSS Windows installation is required (missing $relative in $path). Install the MPSS tools/filesystem supplied with your KNC driver, or pass -MpssDirectory. An INF-only driver is insufficient."
        }
    }
    return $path
}
function Select-PhiAdapter($Adapters,[int]$InterfaceIndex=0) {
    # MIC is a driver-name token, not the prefix of "Microsoft". Hidden
    # Microsoft virtual adapters must never be treated as Phi candidates.
    $candidates=@($Adapters | Where-Object { $_.InterfaceDescription -match '(?i)\bXeon\b.*\bPhi\b|\bMIC\b.*\b(Network|Virtual|Ethernet)\b' })
    if ($InterfaceIndex) { $candidates=@($candidates | Where-Object ifIndex -EQ $InterfaceIndex) }
    if ($candidates.Count -ne 1) { throw 'Expected one Xeon Phi virtual network adapter. Install its MPSS driver; for multiple adapters specify -InterfaceIndex. Physical LAN adapters are never selected.' }
    return $candidates[0]
}
function Convert-PhiIPv4([string]$Address) {
    if ($Address -notmatch '^([0-9]{1,3}\.){3}[0-9]{1,3}$') { throw 'Expected dotted IPv4 address.' }
    $ip=[Net.IPAddress]::Parse($Address)
    $b=$ip.GetAddressBytes()
    return [uint64]$b[0]*16777216+[uint64]$b[1]*65536+[uint64]$b[2]*256+[uint64]$b[3]
}
function Get-PhiSubnet([string]$Address,[int]$PrefixLength) {
    if ($PrefixLength -lt 0 -or $PrefixLength -gt 32) { throw 'Invalid IPv4 prefix.' }
    $size=[uint64][math]::Pow(2,32-$PrefixLength)
    $start=[uint64]([math]::Floor((Convert-PhiIPv4 $Address)/$size)*$size)
    return [pscustomobject]@{start=$start;end=($start+$size-1)}
}
function Read-PhiNetworkXml([string]$Path) {
    $xml=New-Object Xml.XmlDocument
    $xml.XmlResolver=$null; $xml.PreserveWhitespace=$true
    $settings=New-Object Xml.XmlReaderSettings
    $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit; $settings.XmlResolver=$null
    $reader=[Xml.XmlReader]::Create($Path,$settings)
    try { $xml.Load($reader) } finally { $reader.Dispose() }
    foreach ($name in @('IPAddress','HostIPAddress','Subnet','HostSubnet')) {
        if ($xml.SelectNodes('/mic0/Networking/'+$name).Count -ne 1) { throw 'Unsupported MPSS mic0.xml network layout. No settings changed.' }
    }
    return ,$xml
}
function Test-PhiNetworkConflict([string]$Address,[int]$Prefix,$OtherNetworks) {
    $candidate=Get-PhiSubnet $Address $Prefix
    foreach ($other in $OtherNetworks) {
        # Default routes do not reserve the entire IPv4 address space.
        if ([int]$other.prefix -eq 0) { continue }
        $range=Get-PhiSubnet $other.address ([int]$other.prefix)
        if ($candidate.start -le $range.end -and $range.start -le $candidate.end) { return $true }
    }
    return $false
}
function New-PhiNetworkPlan([string]$Mpss,$Adapter,$Addresses,$Routes) {
    $xmlPath=Join-Path $Mpss 'mic0.xml'; $xml=Read-PhiNetworkXml $xmlPath
    $net=$xml.mic0.Networking; $others=@()
    foreach ($a in @($Addresses | Where-Object InterfaceIndex -NE $Adapter.ifIndex)) { $others+=@([pscustomobject]@{address=$a.IPAddress;prefix=$a.PrefixLength}) }
    foreach ($route in @($Routes | Where-Object InterfaceIndex -NE $Adapter.ifIndex)) {
        $parts=$route.DestinationPrefix.Split('/'); $others+=@([pscustomobject]@{address=$parts[0];prefix=[int]$parts[1]})
    }
    $hostIP=[string]$net.HostIPAddress; $cardIP=[string]$net.IPAddress; $keep=$false
    try {
        Assert-PrivateAddress $hostIP; Assert-PrivateAddress $cardIP
        $h=Convert-PhiIPv4 $hostIP; $c=Convert-PhiIPv4 $cardIP
        $subnet=Get-PhiSubnet $hostIP 24
        $keep=($net.Subnet -ceq '255.255.255.0' -and $net.HostSubnet -ceq '255.255.255.0' -and $h -ne $c -and
            $h -gt $subnet.start -and $h -lt $subnet.end -and $c -gt $subnet.start -and $c -lt $subnet.end -and
            !(Test-PhiNetworkConflict $hostIP 24 $others))
    } catch { $keep=$false }
    if (!$keep) {
        $chosen=$false
        foreach ($n in 254..1) {
            $hostIP='172.31.'+$n+'.1'; $cardIP='172.31.'+$n+'.2'
            if (!(Test-PhiNetworkConflict $hostIP 24 $others)) { $chosen=$true; break }
        }
        if (!$chosen) { throw 'No unused private /24 subnet found. Resolve overlapping VPN/LAN routes before setup.' }
    }
    $assigned=@($Addresses | Where-Object { $_.InterfaceIndex -eq $Adapter.ifIndex -and $_.IPAddress -ceq $hostIP })
    if ($assigned.Count -and @($assigned | Where-Object PrefixLength -NE 24).Count) { throw 'The selected Phi host address has a conflicting prefix. Existing addresses were preserved.' }
    return [pscustomobject]@{schema_version=1;mpss=$Mpss;interface_index=[int]$Adapter.ifIndex;
        interface_description=[string]$Adapter.InterfaceDescription;host_address=$hostIP;card_address=$cardIP;prefix=24;
        add_address=($assigned.Count -eq 0);update_xml=(!$keep);xml_input=(Get-IdentityInput $xmlPath)}
}
function Get-PhiHostPlan([string]$MpssDirectory='', [int]$InterfaceIndex=0) {
    Assert-Windows
    $devices=@(Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match '^PCI\\VEN_8086&DEV_225[0-9A-F]' })
    if ($devices.Count -ne 1 -or $devices[0].ConfigManagerErrorCode -ne 0) { throw 'Expected exactly one healthy Intel Xeon Phi KNC card in Device Manager. Finish MPSS driver installation before setup.' }
    $mpss=Find-PhiMpss $MpssDirectory
    $adapter=Select-PhiAdapter @(Get-NetAdapter -IncludeHidden) $InterfaceIndex
    $plan=New-PhiNetworkPlan $mpss $adapter @(Get-NetIPAddress -AddressFamily IPv4) @(Get-NetRoute -AddressFamily IPv4)
    $plan | Add-Member install_openssh ([bool](!(Get-Command ssh.exe -ErrorAction SilentlyContinue) -or !(Get-Command scp.exe -ErrorAction SilentlyContinue) -or !(Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue)))
    $plan | Add-Member device_id ([string]$devices[0].PNPDeviceID)
    if (!(Get-Command tar.exe -ErrorAction SilentlyContinue)) { throw 'Windows tar.exe is required. Use Windows 10 version 1803 or newer with the MPSS driver installed.' }
    return $plan
}
function Enable-PhiTools($Plan) {
    if ($Plan.install_openssh) {
        Write-Host 'Installing the Windows OpenSSH client feature...'
        $result=Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' -ErrorAction Stop
        if ($result.RestartNeeded) { throw 'Windows requires a restart to finish OpenSSH installation. Restart Windows, then run Setup.cmd again.' }
    }
    $sshBin=Join-Path $env:WINDIR 'System32/OpenSSH'
    if (Test-Path -LiteralPath $sshBin) { $env:PATH=$sshBin+';'+$env:PATH }
    foreach ($name in @('ssh.exe','scp.exe','ssh-keygen.exe')) { $null=Get-Command $name -ErrorAction Stop }
}
function Start-PhiServices([string]$Mpss,[string]$Run) {
    $mpssService=Get-Service mpss -ErrorAction Stop
    if ($mpssService.Status -ne 'Running') { $null=Invoke-SetupProcess (Join-Path $Mpss 'bin/micctrl.exe') @('--start') $Run 60000 }
    $ras=Get-Service micras -ErrorAction Stop
    if ($ras.Status -ne 'Running') { Start-Service micras -ErrorAction Stop }
}
function Apply-PhiNetwork($Plan,[string]$Run) {
    # Revalidate the selected hardware and all routes immediately before changes.
    $fresh=Get-PhiHostPlan $Plan.mpss $Plan.interface_index
    foreach ($name in @('device_id','host_address','card_address','interface_description','add_address','update_xml')) {
        if ($fresh.$name -cne $Plan.$name) { throw 'Host network changed since the setup plan. Run setup again.' }
    }
    Assert-IdentityInputs @($Plan.xml_input)
    $backup=Join-Path $Run 'mic0.xml.before'
    Copy-Item -LiteralPath $Plan.xml_input.path -Destination $backup
    if ((Get-FileHash -LiteralPath $backup).Hash -cne $Plan.xml_input.sha256) { throw 'Network backup changed during copy.' }
    $journal=[pscustomobject]@{schema_version=1;plan=$Plan;backup=$backup;added_address=$false;xml_written=$false;dhcp_disabled=$false;state='prepared'}
    Save-Json (Join-Path $Run 'network.json') $journal
    try {
        if ($Plan.add_address) {
            # DHCP on the dedicated Phi adapter is disabled by New-NetIPAddress.
            $ipInterface=Get-NetIPInterface -InterfaceIndex $Plan.interface_index -AddressFamily IPv4
            if ($ipInterface.Dhcp -ne 'Disabled') {
                Set-NetIPInterface -InterfaceIndex $Plan.interface_index -AddressFamily IPv4 -Dhcp Disabled -ErrorAction Stop
                $journal.dhcp_disabled=$true; Save-Json (Join-Path $Run 'network.json') $journal
            }
            $null=New-NetIPAddress -InterfaceIndex $Plan.interface_index -IPAddress $Plan.host_address -PrefixLength 24 -ErrorAction Stop
            $journal.added_address=$true; Save-Json (Join-Path $Run 'network.json') $journal
        }
        if ($Plan.update_xml) {
            $xml=Read-PhiNetworkXml $Plan.xml_input.path
            $xml.mic0.Networking.IPAddress=$Plan.card_address; $xml.mic0.Networking.HostIPAddress=$Plan.host_address
            $xml.mic0.Networking.Subnet='255.255.255.0'; $xml.mic0.Networking.HostSubnet='255.255.255.0'
            $xml.Save($Plan.xml_input.path)
            $journal.xml_written=$true
        }
        $journal.state='applied'; Save-Json (Join-Path $Run 'network.json') $journal
        return $journal
    } catch { Undo-PhiNetwork $journal; throw }
}
function Undo-PhiNetwork($Journal) {
    $plan=$Journal.plan
    if ($Journal.xml_written) {
        if ((Get-FileHash -LiteralPath $Journal.backup).Hash -cne $plan.xml_input.sha256) { throw 'Network backup is damaged; restore stopped.' }
        Copy-Item -LiteralPath $Journal.backup -Destination $plan.xml_input.path -Force
    }
    if ($Journal.added_address) {
        $adapter=Select-PhiAdapter @(Get-NetAdapter -IncludeHidden) $plan.interface_index
        if ($adapter.InterfaceDescription -cne $plan.interface_description) { throw 'Network adapter identity changed; address rollback stopped.' }
        Remove-NetIPAddress -InterfaceIndex $plan.interface_index -IPAddress $plan.host_address -Confirm:$false -ErrorAction Stop
    }
    if ($Journal.dhcp_disabled) { Set-NetIPInterface -InterfaceIndex $plan.interface_index -AddressFamily IPv4 -Dhcp Enabled -ErrorAction Stop }
}
function Test-PhiBootIdentity([string]$Destination,$Plan,[string]$Run) {
    $private=Join-Path $Destination 'app/private'
    $known=Join-Path $private 'known_hosts'
    Write-Utf8 $known ($Plan.address+' '+$Plan.public_key+"`n"); Protect-IdentityFile $known
    $trust=$known.Replace('\','/')
    $args=@('-F','NUL','-o',('UserKnownHostsFile="'+$trust+'"'),'-o','GlobalKnownHostsFile=NUL','-o','StrictHostKeyChecking=yes',
        '-o','BatchMode=yes','-o','IdentitiesOnly=yes','-o','ConnectTimeout=5','-i',(Join-Path $private 'id_ed25519'),'-T',('root@'+$Plan.address),
        'uname -m; cat /etc/phi-chat-identity; cat /proc/sys/kernel/random/boot_id')
    $last=''
    for ($i=0; $i -lt 24; $i++) {
        try {
            $output=Invoke-SetupProcess (Get-Command ssh.exe).Source $args $Run
            $lines=@($output.Trim() -split '\r?\n')
            if ($lines.Count -ne 3 -or $lines[0] -cne 'k1om' -or $lines[1] -cne $Plan.marker -or $lines[2] -notmatch '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$') { throw 'Strict SSH connected but K1OM/boot marker validation failed.' }
            return $lines[2]
        } catch { $last=$_.Exception.Message; Start-Sleep -Seconds 2 }
    }
    throw ('Boot identity could not be verified: '+$last)
}
function Initialize-PhiHost([string]$Destination,$HostPlan,[string]$Run) {
    Enable-PhiTools $HostPlan
    Start-PhiServices $HostPlan.mpss $Run
    $micctrl=Join-Path $HostPlan.mpss 'bin/micctrl.exe'
    $initial=Get-MicState (Invoke-SetupProcess $micctrl @('-s','mic0') $Run)
    if ($initial -notin @('ready','online')) { throw 'Wait for card boot to finish, then run setup again.' }
    $identity=New-PhiClientIdentity $Destination $Run
    # Store the complete transaction, including private backup images, locally.
    $state=Join-Path $Destination 'data/host'; New-Directory $state; Protect-IdentityDirectory $state
    foreach ($sub in @('data/app/config','data/ssh-repair')) { New-Directory (Join-Path $state $sub) }
    Save-Json (Join-Path $state 'data/settings.yaml') ([pscustomobject]@{mpss_dir=$HostPlan.mpss})
    Save-Json (Join-Path $state 'data/app/config/connection.yaml') ([pscustomobject]@{card_address=$HostPlan.card_address})
    $network=Apply-PhiNetwork $HostPlan $Run
    $planDir=Join-Path $state ('data/ssh-repair/'+[Guid]::NewGuid().ToString('N')); New-Directory $planDir
    try {
        $images=@(Get-TreeFiles $HostPlan.mpss @('*.log','*.log.*') | Where-Object Name -Match '^mic0\.image(?:\.gz)?$')
        if (!$images.Count) {
            Write-Host 'Generating the initial MPSS boot image...'
            $null=Invoke-SetupProcess $micctrl @('-g','mic0') $Run 600000
        }
        $plan=New-SshPersistencePlan $state $planDir $identity.directory $identity.server.public $identity.client.public 'first-install'
        $null=Apply-SshPersistencePlan $planDir { param($p) $null=Invoke-SetupProcess $micctrl @('-g','mic0') $Run 600000 }
    } catch { Undo-PhiNetwork $network; throw }
    Save-Json (Join-Path $state 'pending.json') ([pscustomobject]@{plan_directory=$planDir;network_journal=(Join-Path $Run 'network.json')})
    # The interactive installer has already obtained explicit permission to reboot.
    Restart-MicIdentity $initial { Invoke-SetupProcess $micctrl @('-s','mic0') $Run } `
        { $null=Invoke-SetupProcess $micctrl @('-r','mic0') $Run } `
        { $null=Invoke-SetupProcess $micctrl @('-b','mic0') $Run } { Start-Sleep -Seconds 2 }
    $boot=Test-PhiBootIdentity $Destination $plan $Run
    Write-PhiConnection $Destination $HostPlan.mpss $HostPlan.card_address
    $receipt=[pscustomobject]@{schema_version=1;boot_id=$boot;plan_directory=$planDir;network_journal=(Join-Path $Run 'network.json');verified_utc=[DateTime]::UtcNow.ToString('o')}
    Save-Json (Join-Path $state 'verified.json') $receipt
    return $receipt
}
