#Requires -Version 5.1
# Service doubles only. Never call the PC's Service Control Manager or micctrl.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $root 'setup/lib/HostSetup.ps1')
$script:checks=0
function Check([bool]$Value,[string]$Message) { $script:checks++; if (!$Value) { throw ('FAIL: '+$Message) } }
function New-ServiceFixture([string]$Name,[string]$Status) {
    $s=[pscustomobject]@{Name=$Name;Status=$Status;FailWait=$false;Waits=0}
    $s | Add-Member ScriptMethod WaitForStatus {
        param($Wanted,$Timeout)
        $this.Waits++
        if ($this.FailWait) { throw 'Fixture start timeout' }
        if ($Timeout.TotalSeconds -ne 30 -or [string]$Wanted -cne 'Running') { throw 'Unexpected service wait' }
        $this.Status='Running'
    }
    $s | Add-Member ScriptMethod Refresh { }
    return $s
}
function Get-Service {
    param($Name,$ErrorAction)
    $script:queries+=@($Name)
    if ($Name -cnotin @('mpss','micras')) { throw 'Unexpected service query' }
    return $script:services[$Name]
}
function Start-Service {
    param($Name,$ErrorAction)
    if ($Name -cne 'micras') { throw 'Unexpected service start' }
    $script:starts+=@($Name)
    if ($script:failStart) { throw 'Fixture service start denied' }
}
function Invoke-SetupProcess {
    param($Exe,$Arguments,$Run,$Timeout)
    Check ($Exe -ceq (Join-Path $script:mpss 'bin/micctrl.exe') -and $Arguments.Count -eq 1 -and $Arguments[0] -ceq '--start' -and $Timeout -eq 60000) 'only the exact MPSS start operation is allowed'
    $script:stackStarts++
}
function Reset-Fixture {
    $script:services=@{micras=(New-ServiceFixture micRAS Stopped)}
    $script:queries=@(); $script:starts=@(); $script:stackStarts=0; $script:failStart=$false
}
function Reject([string]$Pattern) {
    $rejected=$false
    try { Start-PhiServices $script:mpss 'unused fixture run' } catch { $rejected=$_.Exception.Message -like $Pattern }
    Check $rejected ('stops with diagnostic: '+$Pattern)
}
$script:mpss=Join-Path ([IO.Path]::GetTempPath()) 'fixture MPSS never executed'
Reset-Fixture
Start-PhiServices $script:mpss 'unused fixture run'
Check ($script:stackStarts -eq 0 -and $script:starts.Count -eq 1 -and $script:services.micras.Waits -eq 1) 'reported layout: absent mpss is allowed; stopped micRAS starts and is awaited'
Check (($script:queries -join ',') -ceq 'micras,mpss') 'only exact names queried; Windows Firewall mpssvc is never touched'
Reset-Fixture
$script:services.mpss=New-ServiceFixture mpss Stopped
Start-PhiServices $script:mpss 'unused fixture run'
Check ($script:stackStarts -eq 1 -and $script:services.mpss.Waits -eq 1) 'registered stopped stack starts through micctrl and is awaited'
Reset-Fixture
foreach ($name in @('mpss','micras')) { $script:services[$name]=New-ServiceFixture $name Running }
Start-PhiServices $script:mpss 'unused fixture run'
Check ($script:stackStarts -eq 0 -and !$script:starts.Count) 'running services are not restarted'
Reset-Fixture
foreach ($name in @('mpss','micras')) { $script:services[$name]=New-ServiceFixture $name StartPending }
Start-PhiServices $script:mpss 'unused fixture run'
Check ($script:stackStarts -eq 0 -and !$script:starts.Count -and $script:services.micras.Waits -eq 1) 'pending starts are awaited without restarting services'
Reset-Fixture
$script:services=@{mpss=(New-ServiceFixture mpss Stopped)}
Reject '*micRAS telemetry service is missing*'
Check ($script:stackStarts -eq 0 -and !$script:starts.Count) 'missing telemetry fails before any service mutation'
Reset-Fixture
$script:services.micras.Status='StopPending'
Reject '*StopPending*'
Check (!$script:starts.Count) 'stopping service is not restarted'
Reset-Fixture
$script:services.micras.FailWait=$true
Reject '*micRAS did not start*'
Reset-Fixture
$script:failStart=$true
Reject '*start denied*'
Write-Output ('PASS: '+$script:checks+' MPSS service regression checks; no real services or card commands called.')
