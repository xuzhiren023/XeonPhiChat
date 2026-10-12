# Hardware-free transaction tests. All SSH/MPSS/native results below are mocks.
param([Parameter(Mandatory=$true)][string]$Scratch)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$script:root=Split-Path $PSScriptRoot -Parent
. (Join-Path $script:root 'lib/ChatCore.ps1')
. (Join-Path $script:root 'lib/GccRuntime.ps1')
function Assert([bool]$Ok,[string]$Message) { if (!$Ok) { throw $Message } }
$actualRoot=$script:root
$script:root=Join-Path $Scratch 'app'
$script:data=Join-Path $Scratch 'data'
$script:job=Join-Path $Scratch 'job'
$package=Join-Path $Scratch 'package'
$null=New-Item -ItemType Directory -Force -Path (Join-Path $script:root 'config'),$script:data,$script:job,$package
$script:cfg=[pscustomobject]@{source_commit='03a8b80c7d502797325788f604248dd4aabdf5ef';heartbeat_timeout_seconds=35}
$script:health=[pscustomobject]@{serial='FIXTURE123';profile=[pscustomobject]@{profile_id='xeon-phi-3120a'}}
$script:ssh='ssh';$script:scp='scp';$script:scpMode=@();$script:sshOptions=@();$script:target='root@fixture.invalid'
$script:cardLockToken=('a'*32);$script:locked=$false;$script:guarded=$false;$script:mode='pass';$script:sent='';$script:calls=0
$bytes=New-Object byte[] 2048
[IO.File]::WriteAllBytes((Join-Path $package 'runtime-3120A.tar'),$bytes)
$payload=[pscustomobject]@{profile='xeon-phi-3120a';file='runtime-3120A.tar';runtime_id=('phichat138-gcc021-'+('b'*16));bytes=2048;sha256=(Get-FileHash (Join-Path $package 'runtime-3120A.tar')).Hash.ToLowerInvariant()}
Write-JsonFile (Join-Path $script:root 'config/gcc-runtime.json') ([pscustomobject]@{version='1.3.8';source_commit=$script:cfg.source_commit;kernel_version='0.2.1';payloads=@($payload)})
function Acquire-CardWorkloadLock { Assert (!$script:locked) 'lock twice';$script:locked=$true }
function Release-CardWorkloadLock { $script:locked=$false }
function Set-JobStatus { param($Message) }
function Read-CardHealth { return $script:health }
function Send-CardFiles { param($Local,$Remote);Assert $script:locked 'transfer without ownership';$script:sent=$Local[0] }
function Invoke-Card {
    param($Command)
    $script:calls++
    if ($Command -eq 'cat /proc/meminfo') { return "MemTotal: 6000000 kB`nMemFree: 5000000 kB`n" }
    if ($Command.StartsWith("cat '") -and $Command.Contains('gcc-runtime-passed.txt')) {
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
        Assert ([bool]$Guarded -and $Seconds -eq 930 -and $Arguments[-1].Contains('/guard')) 'native execution not guarded'
        $script:guarded=$true
        if ($script:mode -eq 'native') { throw 'fixture native numerical failure' }
    }
    return ''
}
$baseline=[pscustomobject]@{source_commit=$script:cfg.source_commit;remote_base='/root/knc-phase3-run-baseline';runtime_archive='unchanged-baseline.tar';evidence='unchanged'}
$path=Get-GccSelectionPath $script:data $script:health
Assert ((Resolve-GccRuntime $baseline).remote_base -ceq $baseline.remote_base) 'baseline fallback'
foreach ($failure in @('corrupt','native','receipt')) {
    $script:mode=$failure
    $failed=$false
    try { $null=Install-GccCardRuntime $baseline $package } catch { $failed=$true }
    Assert $failed ('missing rejection '+$failure)
    Assert (!(Test-Path $path) -and !$script:locked) ('published failed runtime or retained lock '+$failure)
}
$script:mode='pass'
$selection=Install-GccCardRuntime $baseline $package
Assert ($script:guarded -and !$script:locked -and (Test-Path $path)) 'successful fixture was not published'
$resolved=Resolve-GccRuntime $baseline
Assert ($resolved.remote_base -ceq $selection.remote_base -and $resolved.runtime_archive -ceq 'unchanged-baseline.tar') 'runtime routing changed baseline backup'
Assert ($baseline.remote_base -ceq '/root/knc-phase3-run-baseline') 'baseline object mutated'
# A failed reinstall must keep the previous selected runtime byte-for-byte.
$before=[IO.File]::ReadAllText($path);$script:mode='native'
try { $null=Install-GccCardRuntime $baseline $package;throw 'missing failure' } catch { Assert ($_.Exception.Message -match 'fixture native') 'wrong reinstall error' }
Assert ([IO.File]::ReadAllText($path) -ceq $before) 'failed reinstall changed active receipt'
$script:health.serial='OTHER-CARD'
Assert ((Resolve-GccRuntime $baseline).remote_base -ceq $baseline.remote_base) 'cross-card activation'
$script:health.serial='FIXTURE123'
$invalid=Read-JsonFile $path;$invalid.profile='xeon-phi-7120p';Write-JsonFile $path $invalid
$failed=$false;try { $null=Resolve-GccRuntime $baseline } catch { $failed=$true }
Assert $failed 'wrong SKU selection accepted'
[IO.File]::WriteAllText($path,$before)
Disable-GccRuntime
Assert ((Resolve-GccRuntime $baseline).remote_base -ceq $baseline.remote_base -and !$script:locked) 'rollback failed'
Write-Host 'PASS: mocked runtime transactions: hash, native failure, receipt identity, atomic activation, card/SKU isolation and rollback. No native execution.'
