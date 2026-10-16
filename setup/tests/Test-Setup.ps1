#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'setup/lib/HostSetup.ps1')
$checks=0
function Check([bool]$Value,[string]$Message) { $script:checks++; if (!$Value) { throw ('FAIL: '+$Message) } }
function Reject([scriptblock]$Action,[string]$Message) { $failed=$false; try { & $Action | Out-Null } catch { $failed=$true }; Check $failed $Message }
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('phi-setup-'+[Guid]::NewGuid().ToString('N'))
New-Directory $scratch
try {
    $mpss=Join-Path $scratch 'mock MPSS'; New-Directory $mpss
    $xmlPath=Join-Path $mpss 'mic0.xml'
    Write-Utf8 $xmlPath '<mic0><Hostname>preserved</Hostname><Networking><IPAddress>192.168.1.100</IPAddress><HostIPAddress>192.168.1.99</HostIPAddress><Subnet>255.255.255.0</Subnet><HostSubnet>255.255.255.0</HostSubnet><MACAddress>00:11:22:33:44:00</MACAddress></Networking></mic0>'
    $phi=[pscustomobject]@{ifIndex=7;InterfaceDescription='Intel Xeon Phi Virtual Ethernet'}
    $lan=[pscustomobject]@{ifIndex=1;InterfaceDescription='Intel Ethernet LAN'}
    Check ((Select-PhiAdapter @($phi,$lan)).ifIndex -eq 7) 'only Phi adapter chosen'
    $wifi=[pscustomobject]@{ifIndex=9;InterfaceDescription='Microsoft Wi-Fi Direct Virtual Adapter'}
    $wifi3=[pscustomobject]@{ifIndex=8;InterfaceDescription='Microsoft Wi-Fi Direct Virtual Adapter #3'}
    $debug=[pscustomobject]@{ifIndex=3;InterfaceDescription='Microsoft Kernel Debug Network Adapter'}
    $realPhi=[pscustomobject]@{ifIndex=10;InterfaceDescription='Intel(R) Xeon Phi(TM) coprocessor Virtual Ethernet Adapter (x64)'}
    Check ((Select-PhiAdapter @($realPhi,$wifi,$wifi3,$debug,$lan)).ifIndex -eq 10) 'real driver name wins over Microsoft hidden virtual adapters'
    Reject { Select-PhiAdapter @($wifi,$wifi3,$debug) } 'Microsoft devices alone never count as MIC adapters'
    Reject { Select-PhiAdapter @($realPhi,$wifi) 9 } 'explicit Microsoft virtual interface rejected'
    $mic=[pscustomobject]@{ifIndex=11;InterfaceDescription='Intel MIC Virtual Ethernet Adapter'}
    Check ((Select-PhiAdapter @($mic,$wifi)).ifIndex -eq 11) 'standalone MIC driver-name token is supported'
    Reject { Select-PhiAdapter @($phi,$lan) 1 } 'explicit physical LAN index rejected'
    Reject { Select-PhiAdapter @($phi,$phi) } 'ambiguous Phi adapter rejected'
    $plan=New-PhiNetworkPlan $mpss $phi @() @()
    Check ($plan.card_address -ceq '192.168.1.100' -and !$plan.update_xml -and $plan.add_address) 'valid unoccupied MPSS subnet retained'
    $assigned=@([pscustomobject]@{InterfaceIndex=7;IPAddress='192.168.1.99';PrefixLength=24})
    Check (!(New-PhiNetworkPlan $mpss $phi $assigned @()).add_address) 'existing matching Phi address reused'
    $addresses=@([pscustomobject]@{InterfaceIndex=1;IPAddress='192.168.1.10';PrefixLength=24})
    $routes=@([pscustomobject]@{InterfaceIndex=1;DestinationPrefix='172.31.254.0/24'},[pscustomobject]@{InterfaceIndex=1;DestinationPrefix='0.0.0.0/0'})
    $plan=New-PhiNetworkPlan $mpss $phi $addresses $routes
    Check ($plan.host_address -ceq '172.31.253.1' -and $plan.card_address -ceq '172.31.253.2') 'LAN and VPN overlaps avoided; default route allowed'
    Reject { New-PhiNetworkPlan $mpss $phi $addresses @([pscustomobject]@{InterfaceIndex=1;DestinationPrefix='172.16.0.0/12'}) } 'exhausted address candidates fail without host writes'
    Reject { Convert-PhiIPv4 '192.168.1' } 'abbreviated IPv4 rejected'
    $plan | Add-Member device_id 'fixture-only'
    $script:mockPlan=$plan; $script:networkEvents=New-Object Collections.ArrayList
    function Get-PhiHostPlan { param($MpssDirectory,$InterfaceIndex); return $script:mockPlan }
    function Get-NetAdapter { param([switch]$IncludeHidden); return $phi }
    function Get-NetIPInterface { param($InterfaceIndex,$AddressFamily); [pscustomobject]@{Dhcp='Enabled'} }
    function Set-NetIPInterface { param($InterfaceIndex,$AddressFamily,$Dhcp,$ErrorAction); Check ($InterfaceIndex -eq 7) 'DHCP changes only Phi NIC'; $null=$script:networkEvents.Add('dhcp-'+$Dhcp) }
    function New-NetIPAddress { param($InterfaceIndex,$IPAddress,$PrefixLength,$ErrorAction); Check ($InterfaceIndex -eq 7 -and $PrefixLength -eq 24) 'address changes only Phi NIC'; $null=$script:networkEvents.Add('add-'+$IPAddress) }
    function Remove-NetIPAddress { param($InterfaceIndex,$IPAddress,$Confirm,$ErrorAction); Check ($InterfaceIndex -eq 7) 'rollback only Phi NIC'; $null=$script:networkEvents.Add('remove-'+$IPAddress) }
    $run=Join-Path $scratch 'network-run'; New-Directory $run
    $journal=Apply-PhiNetwork $plan $run
    $changed=Read-PhiNetworkXml $xmlPath
    Check ($changed.mic0.Networking.IPAddress -ceq '172.31.253.2' -and $changed.mic0.Hostname -ceq 'preserved' -and $changed.mic0.Networking.MACAddress -ceq '00:11:22:33:44:00') 'network XML preserves unrelated fields'
    Undo-PhiNetwork $journal
    Check ((Get-FileHash -LiteralPath $xmlPath).Hash -ceq $plan.xml_input.sha256) 'network rollback restores exact XML bytes'
    Check (($script:networkEvents -join ',') -ceq 'dhcp-Disabled,add-172.31.253.1,remove-172.31.253.1,dhcp-Enabled') 'DHCP/address transaction rolls back in order'

    $install=Join-Path $scratch 'fresh install'
    $receipt=Copy-PhiApplication $root $install
    Check ($receipt.status -ceq 'copied' -and !(Test-Path -LiteralPath (Join-Path $install 'app/config/connection.yaml'))) 'fresh app has no copied machine configuration'
    Check (!(Test-Path -LiteralPath (Join-Path $install 'app/data')) -and !(Test-Path -LiteralPath (Join-Path $install 'app/private'))) 'fresh copy has no history or identity'
    Check ((Copy-PhiApplication $root $install).source_files.Count -eq $receipt.source_files.Count) 'same-version copy resumes'
    Check (!(Test-Path -LiteralPath (Join-Path $install 'app/Test-ModernRuntime.ps1'))) 'source installs omit developer files just like the Windows ZIP'
    # Reproduce the 1.6.5 source-install receipt, then retry using ZIP contents.
    $download=Join-Path $scratch 'extracted installer'; $null=Copy-PhiApplication $root $download
    Remove-Item -LiteralPath (Join-Path $download 'installation.json')
    $developerFile=Join-Path $install 'app/Test-ModernRuntime.ps1'; Write-Utf8 $developerFile '# old developer script'
    $receipt.source_files+=@([pscustomobject]@{path='app/Test-ModernRuntime.ps1';sha256=(Get-FileHash -LiteralPath $developerFile).Hash.ToLowerInvariant()})
    Save-Json (Join-Path $install 'installation.json') $receipt
    Add-Content -LiteralPath $developerFile '# user edit'
    $null=Copy-PhiApplication $download $install
    Check ((Read-SmallText $developerFile).Contains('# user edit')) 'ZIP retry ignores obsolete developer receipt entries and preserves edits'
    $production=Join-Path $download 'app/lib/ChatCore.ps1'; $original=[IO.File]::ReadAllBytes($production)
    Remove-Item -LiteralPath $production
    Reject { Copy-PhiApplication $download $install } 'missing production file still rejects an incomplete installer'
    [IO.File]::WriteAllBytes($production,$original)
    Add-Content -LiteralPath $production '# modified download'
    Reject { Copy-PhiApplication $download $install } 'changed production file still rejects a mismatched installer'
    [IO.File]::WriteAllBytes($production,$original)
    $foreign=Join-Path $scratch 'foreign'; New-Directory $foreign; Write-Utf8 (Join-Path $foreign 'keep.txt') 'keep'
    Reject { Copy-PhiApplication $root $foreign } 'unrelated destination preserved'
    Reject { Copy-PhiApplication $root (Join-Path $root 'nested') } 'nested installation rejected'
    $startup=Join-Path $install 'Start.ps1'; Add-Content -LiteralPath $startup '# user edit'
    Reject { Copy-PhiApplication $root $install } 'edited installed code preserved'

    $fixture=Join-Path $scratch 'release assets'; New-Directory (Join-Path $fixture 'assets/payloads')
    Write-Utf8 (Join-Path $fixture 'VERSION') (Get-PhiVersion $root)
    $manifest=Read-PhiAssetManifest $root
    foreach ($asset in $manifest.assets) {
        $file=Join-Path $fixture ('assets/payloads/'+$asset.file); Write-Utf8 $file ('fixture archive '+('x'*2048))
        $asset.bytes=(Get-Item -LiteralPath $file).Length; $asset.sha256=(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()
    }
    Save-Json (Join-Path $fixture 'assets/runtime-manifest.json') $manifest
    $null=Get-PhiAssets $fixture ''
    Install-PhiAssets $fixture '' $install
    $prime=@($manifest.assets | Where-Object kind -CEQ 'priming')[0]
    Check (Test-Path -LiteralPath (Join-Path $install ('app/data/priming-runtime/payload-'+$prime.sha256+'/'+$prime.file))) 'priming dependency installs into its own pinned cache'
    foreach ($scif in @($manifest.assets | Where-Object kind -CEQ 'scif-transfer')) {
        Check (Test-Path -LiteralPath (Join-Path $install ('app/data/scif-transfer/payload-'+$scif.sha256+'/'+$scif.file))) ('SCIF dependency installs without a compiler: '+$scif.file)
    }
    $vision=@($manifest.assets | Where-Object kind -CEQ 'vision-projector')[0]
    $visionFile=Get-Item -LiteralPath (Join-Path $install ('app/'+$vision.model_path))
    $visionReceipt=Read-Json (Join-Path $install ('app/data/model-'+$vision.model_id+'.json'))
    Check ($visionFile.Length -eq $vision.bytes -and $visionReceipt.path -ceq $visionFile.FullName -and $visionReceipt.modified_ticks -eq $visionFile.LastWriteTimeUtc.Ticks -and $visionReceipt.sha256 -ceq $vision.sha256) 'fresh setup includes the Step3 projector and its reusable admission receipt'
    $baseline=Read-Json (Join-Path $install 'app/dependencies/phase3/artifacts/last-build.json')
    Check (!$baseline.native_acceptance -and $baseline.kind -ceq 'watchdog-bootstrap-only') 'bootstrap receipt cannot claim native validation'
    Add-Content -LiteralPath (Join-Path $fixture 'assets/payloads/runtime-7120P.tar') 'corrupt'
    Reject { Get-PhiAssets $fixture '' } 'corrupt native asset rejected'
    $manifest.assets[0].file='../escape.tar'; Save-Json (Join-Path $fixture 'assets/runtime-manifest.json') $manifest
    Reject { Get-PhiAssets $fixture '' } 'asset traversal rejected'

    $keyrun=Get-PhiSetupRun $install
    # Real disposable ED25519 key creation, no existing user credentials.
    $identity=New-PhiClientIdentity $install $keyrun
    $again=New-PhiClientIdentity $install $keyrun
    Check ($identity.client.fingerprint -ceq $again.client.fingerprint -and $identity.server.fingerprint -ceq $again.server.fingerprint) 'retry reuses generated keys without rotation'
    Write-PhiConnection $install $mpss '172.31.253.2'
    . (Join-Path $root 'app/lib/ChatCore.ps1')
    $connection=Read-PhiConnection (Join-Path $install 'app')
    Check ($connection.micinfo -ceq (Join-Path $mpss 'bin/MicInfo.exe') -and (Test-Within $connection.key_path $install)) 'installed system tools allowed; new identity stays local'
    $json=Read-Json (Join-Path $install 'app/config/connection.yaml'); $json.data_dir='../escape'
    Save-Json (Join-Path $install 'app/config/connection.yaml') $json
    Reject { Read-PhiConnection (Join-Path $install 'app') } 'system dependencies flag does not allow state path escape'

    $pack=Join-Path $scratch 'model pack'; New-Directory (Join-Path $pack 'models/uniform-q5-k')
    $models=Read-Json (Join-Path $root 'assets/optimized-models.json')
    foreach ($model in $models.models) {
        $file=Join-Safe $pack $model.path; Write-Utf8 $file ('test '+$model.id)
        if ($model.id -ceq $vision.model_id) {Copy-Item -LiteralPath $visionFile.FullName -Destination $file -Force}
        $model.bytes=(Get-Item -LiteralPath $file).Length; $model.sha256=(Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant()
    }
    Save-Json (Join-Path $fixture 'assets/optimized-models.json') $models
    $null=Import-PhiOptimizedModels $fixture $install $pack
    $null=Import-PhiOptimizedModels $fixture $install $pack
    Check (@(Get-ChildItem -LiteralPath (Join-Path $install 'app/models/uniform-q5-k')).Count -eq $models.models.Count) 'all pinned models import and retry verified'
    $blocked=@($models.models | Where-Object { $_.PSObject.Properties['runtime_status'] -and $_.runtime_status -ceq 'experimental_lfm2moe' })
    Check ($blocked.Count -eq 1) 'one pinned Gaston model uses the experimental MoE runtime'
    $gaston=Import-PhiOptimizedModels $fixture $install $pack @($blocked[0].id)
    Check ($gaston.count -eq 1 -and $gaston.blocked_model_ids.Count -eq 0 -and !$gaston.runtime_acceptance_changed) 'Gaston import does not create native acceptance'
    $one=Join-Path $scratch 'single model pack'; New-Directory (Join-Path $one 'models/uniform-q5-k')
    Copy-Item -LiteralPath (Join-Safe $pack $models.models[0].path) -Destination (Join-Safe $one $models.models[0].path)
    $single=Import-PhiOptimizedModels $fixture $install $one
    Check ($single.count -eq 1 -and !$single.runtime_acceptance_changed) 'single-model pack imports without granting runtime acceptance'
    Reject { Import-PhiOptimizedModels $fixture $install $one @($models.models[1].id) } 'explicitly requested missing model fails'
    Reject { Import-PhiOptimizedModels $fixture $install $one @('untrusted-model') } 'unknown model ID cannot be imported'
    $duplicate=$models | ConvertTo-Json -Depth 12 | ConvertFrom-Json; $duplicate.models[1].id=$duplicate.models[0].id
    Save-Json (Join-Path $fixture 'assets/optimized-models.json') $duplicate
    Reject { Import-PhiOptimizedModels $fixture $install $one } 'duplicate manifest identities rejected'
    $duplicate.models[1].id='escape-model'; $duplicate.models[1].path='../outside.gguf'
    Save-Json (Join-Path $fixture 'assets/optimized-models.json') $duplicate
    Reject { Import-PhiOptimizedModels $fixture $install $one } 'manifest path traversal rejected before writes'
    Save-Json (Join-Path $fixture 'assets/optimized-models.json') $models
    $conflict=Join-Path $scratch 'conflicting installed models'
    $badTarget=Join-Safe (Join-Path $conflict 'app') $models.models[1].path
    New-Directory (Split-Path $badTarget -Parent); Write-Utf8 $badTarget 'unrelated existing weights'
    Reject { Import-PhiOptimizedModels $fixture $conflict $pack } 'existing model conflicts are checked before any copy'
    Check (!(Test-Path -LiteralPath (Join-Safe (Join-Path $conflict 'app') $models.models[0].path))) 'later model conflict cannot leave earlier model newly installed'
    Add-Content -LiteralPath (Join-Safe $pack $models.models[1].path) 'bad'
    Reject { Import-PhiOptimizedModels $fixture $install $pack } 'tampered model pack rejected'
    Write-Output ('PASS: '+$checks+' standalone setup checks; all host network operations mocked, only disposable keys/files created.')
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^phi-setup-[a-f0-9]{32}$') { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
