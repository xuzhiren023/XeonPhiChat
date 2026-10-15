# Hardware-free transaction tests. All SSH/MPSS/native results below are mocks.
param([Parameter(Mandatory=$true)][string]$Scratch)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$script:root=Split-Path $PSScriptRoot -Parent
. (Join-Path $script:root 'lib/ChatCore.ps1')
. (Join-Path $script:root 'lib/ModernRuntime.ps1')
function Assert([bool]$Ok,[string]$Message) { if (!$Ok) { throw $Message } }
$actualRoot=$script:root
$script:root=Join-Path $Scratch 'app'
$script:data=Join-Path $Scratch 'data'
$script:job=Join-Path $Scratch 'job'
$package=Join-Path $Scratch 'package'
$null=New-Item -ItemType Directory -Force -Path (Join-Path $script:root 'config'),$script:data,$script:job,$package
foreach ($pinFile in @(Get-ChildItem -LiteralPath (Join-Path $actualRoot 'config') -Filter 'modern-runtime*.json')) {
    Copy-Item -LiteralPath $pinFile.FullName -Destination (Join-Path $script:root ('config/'+$pinFile.Name))
}
$script:cfg=[pscustomobject]@{source_commit='03a8b80c7d502797325788f604248dd4aabdf5ef';heartbeat_timeout_seconds=35}
$script:health=[pscustomobject]@{serial='FIXTURE123';profile=[pscustomobject]@{profile_id='xeon-phi-3120a'}}
$script:ssh='ssh';$script:scp='scp';$script:scpMode=@();$script:sshOptions=@();$script:target='root@fixture.invalid'
$script:cardLockToken=('a'*32);$script:locked=$false;$script:guarded=$false;$script:mode='pass';$script:sent='';$script:calls=0
$script:installMode='';$script:present=''
$bytes=New-Object byte[] 2048
[IO.File]::WriteAllBytes((Join-Path $package 'runtime-3120A.tar'),$bytes)
$payload=[pscustomobject]@{profile='xeon-phi-3120a';file='runtime-3120A.tar';runtime_id=('phichat142-modern-'+('b'*16));bytes=2048;sha256=(Get-FileHash (Join-Path $package 'runtime-3120A.tar')).Hash.ToLowerInvariant()}
Write-JsonFile (Join-Path $script:root 'config/modern-runtime.json') ([pscustomobject]@{version='1.4.2';source_commit=$script:cfg.source_commit;kernel_version='0.2.1';modern_source_commit='d57e0e6e4882445bc625aaee47f91db469f9fc22';payloads=@($payload)})
function Install-RuntimeGuard { param($Baseline,$Remote); Assert $script:locked 'guard staging without ownership' }
function Acquire-CardWorkloadLock { Assert (!$script:locked) 'lock twice';$script:locked=$true }
function Release-CardWorkloadLock { $script:locked=$false; if ($script:mode -ceq 'cleanup') { throw 'fixture cleanup failure' } }
function Set-JobStatus { param($Message) }
function Read-CardHealth { return $script:health }
function Send-CardFiles { param($Local,$Remote);Assert $script:locked 'transfer without ownership';$script:sent=$Local[0] }
function Invoke-Card {
    param($Command)
    $script:calls++
    if ($Command -eq 'cat /proc/meminfo') { return "MemTotal: 6000000 kB`nMemFree: 5000000 kB`n" }
    if ($Command.StartsWith('if test -x')) { return $script:present }
    if ($Command.StartsWith("cat '") -and $Command.Contains('modern-runtime-passed.txt')) {
        if ($script:mode -eq 'receipt') { return 'wrong-identity' }
        return $payload.runtime_id
    }
    return ''
}
function Invoke-JobProcess {
    param($Exe,$Arguments,$Seconds,$OutputPath,[switch]$Guarded)
    Assert $script:locked 'native/transfer without ownership'
    if ($Exe -eq 'scp') {
        Copy-Item -LiteralPath $script:sent -Destination $Arguments[-1]
        if ($script:mode -eq 'corrupt') { [IO.File]::WriteAllText($Arguments[-1],'corrupt transfer fixture') }
    } else {
        $command=$Arguments[-1]
        $script:installMode=if ($command.EndsWith("'restore'")) {'restore'} else {'qualify'}
        $timeout=if ($script:installMode -ceq 'restore') {120} else {900}
        Assert ([bool]$Guarded -and $Seconds -eq $timeout+30 -and $command.Contains("/guard' $timeout 35 bash")) 'native execution not guarded with bounded timeout and heartbeat'
        $script:guarded=$true
        if ($script:mode -eq 'native') { throw 'fixture native numerical failure' }
    }
    return ''
}
$baseline=[pscustomobject]@{source_commit=$script:cfg.source_commit;remote_base='/root/knc-phase3-run-baseline';runtime_archive='unchanged-baseline.tar';evidence='unchanged'}
$path=Get-ModernSelectionPath $script:data $script:health
Assert ((Resolve-ModernRuntime $baseline).remote_base -ceq $baseline.remote_base) 'baseline fallback'
foreach ($failure in @('corrupt','native','receipt')) {
    $script:mode=$failure
    $failed=$false
    try { $null=Install-ModernCardRuntime $baseline $package } catch { $failed=$true }
    Assert $failed ('missing rejection '+$failure)
    Assert (!(Test-Path $path) -and !$script:locked) ('published failed runtime or retained lock '+$failure)
}
$script:mode='pass'
$selection=Install-ModernCardRuntime $baseline $package
Assert ($script:guarded -and !$script:locked -and (Test-Path $path)) 'successful fixture was not published'
Assert ($script:installMode -ceq 'qualify' -and !$selection.PSObject.Properties['restoration']) 'first installation skipped native qualification'
$resolved=Resolve-ModernRuntime $baseline
Assert ($resolved.remote_base -ceq $selection.remote_base -and $resolved.runtime_archive -ceq 'unchanged-baseline.tar') 'runtime routing changed baseline backup'
Assert ($resolved.modern_source_commit -ceq 'd57e0e6e4882445bc625aaee47f91db469f9fc22') 'new runtime source identity was not propagated'
Assert ($baseline.remote_base -ceq '/root/knc-phase3-run-baseline') 'baseline object mutated'
# Reconnect after a cold boot reuses only the same card/archive acceptance.
$selection.evidence='original native acceptance';$selection.created_utc='2026-10-01T00:00:00Z';Write-JsonFile $path $selection
$restored=Resolve-ModernRuntime $baseline -RestoreMissing
$after=Read-JsonFile $path
Assert ($script:installMode -ceq 'restore' -and $restored.remote_base -cne $selection.remote_base) 'cold boot did not choose the short restoration route'
Assert ($after.evidence -ceq $selection.evidence -and $after.created_utc -ceq $selection.created_utc -and $after.restoration.validation -ceq 'accepted-archive-and-cli-startup') 'restoration rewrote inherited native acceptance'
$script:installMode='';$script:present=$payload.runtime_id
$null=Resolve-ModernRuntime $baseline -RestoreMissing
Assert (!$script:installMode) 'repeated connection reinstalled an already present runtime'
$script:present=''
foreach ($field in @('serial','profile','archive_sha256','version','validation')) {
    $invalid=Read-JsonFile $path;$invalid.$field='mismatched';Write-JsonFile $path $invalid
    $script:installMode='';$failed=$false
    try { $null=Install-ModernCardRuntime $baseline $package } catch { $failed=$true }
    Assert ($failed -and !$script:installMode -and !$script:locked) ('mismatched acceptance reused: '+$field)
    Write-JsonFile $path $after
}
# A failed reinstall must keep the previous selected runtime byte-for-byte.
$before=[IO.File]::ReadAllText($path);$script:mode='native'
try { $null=Install-ModernCardRuntime $baseline $package;throw 'missing failure' } catch { Assert ($_.Exception.Message -match 'fixture native') 'wrong reinstall error' }
Assert ([IO.File]::ReadAllText($path) -ceq $before) 'failed reinstall changed active receipt'
$script:mode='cleanup'
try { $null=Install-ModernCardRuntime $baseline $package;throw 'missing failure' } catch { Assert ($_.Exception.Message -match 'fixture cleanup') 'wrong cleanup error' }
Assert ([IO.File]::ReadAllText($path) -ceq $before) 'unconfirmed restore cleanup changed active receipt'
$script:health.serial='OTHER-CARD'
Assert ((Resolve-ModernRuntime $baseline).remote_base -ceq $baseline.remote_base) 'cross-card activation'
$script:mode='pass';$null=Install-ModernCardRuntime $baseline $package
Assert ($script:installMode -ceq 'qualify') 'new card reused another card acceptance'
$script:health.serial='FIXTURE123'
$invalid=Read-JsonFile $path;$invalid.profile='xeon-phi-7120p';Write-JsonFile $path $invalid
$failed=$false;try { $null=Resolve-ModernRuntime $baseline } catch { $failed=$true }
Assert $failed 'wrong SKU selection accepted'
[IO.File]::WriteAllText($path,$before)
Disable-ModernRuntime
Assert ((Resolve-ModernRuntime $baseline).remote_base -ceq $baseline.remote_base -and !$script:locked) 'rollback failed'
Write-Host 'PASS: mocked runtime transactions: hash, native failure, receipt identity, atomic activation, card/SKU isolation and rollback. No native execution.'
# Roll back 1.4.2 to an existing 1.4.0 selection without losing its package pin.
$oldPayload=$payload.PSObject.Copy();$oldPayload.runtime_id=('phichat140-modern-'+('c'*16))
Write-JsonFile (Join-Path $script:root 'config/modern-runtime-1.4.0.json') ([pscustomobject]@{version='1.4.0';source_commit=$script:cfg.source_commit;kernel_version='0.2.1';modern_source_commit='6783b11fb0889d68d0046176b4cc92ceee1961b0';payloads=@($oldPayload)})
$oldSelection=$selection.PSObject.Copy();$oldSelection.version='1.4.0';$oldSelection.runtime_id=$oldPayload.runtime_id;$oldSelection.remote_base='/root/knc-phase3-run-modern140-fixture'
Write-JsonFile $path $oldSelection
Assert ((Resolve-ModernRuntime $baseline).modern_runtime_version -ceq '1.4.0') 'old selection cannot be resolved after app update'
$script:mode='pass';$null=Install-ModernCardRuntime $baseline $package
Assert ($script:installMode -ceq 'qualify') 'changed runtime reused earlier runtime acceptance'
Assert ((Resolve-ModernRuntime $baseline).modern_runtime_version -ceq '1.4.2') 'new version was not selected'
Disable-ModernRuntime
$restored=Resolve-ModernRuntime $baseline
Assert ($restored.modern_runtime_version -ceq '1.4.0' -and $restored.remote_base -ceq $oldSelection.remote_base) 'previous modern runtime rollback failed'
Assert (!(Test-Path ($path+'.previous.json'))) 'rollback receipt was not consumed'
Assert ($restored.modern_source_commit -ceq '6783b11fb0889d68d0046176b4cc92ceee1961b0') 'rollback lost the original source revision'
Write-Host 'PASS: 1.4.0 selection survives app update; 1.4.2 activation and rollback restore its exact runtime identity.'
