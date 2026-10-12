# Run with Windows PowerShell 5.1 or PowerShell 7. No hardware needed.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/Hardware.ps1')
$profiles = @(Get-ChildItem (Join-Path $root 'config/hardware') -Filter '*.yaml' |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
$active = @'
Device No: 0, Device Name: mic0
Board SKU : C0PRQ-3120/3140 P/A
SMC HW Revision : Product 300W Active CS
ECC Mode : Enabled
Total No of Active Cores : 57
Frequency : 1100000 kHz
Fan RPM : 2700
Die Temp : 53 C
GDDR Size : 5952 MB
'@
$passed = 0
function Reject([string]$Name, [string]$Text) {
    $rejected = $false
    try { $null = Read-MicHardware -Text $Text -Profiles $profiles }
    catch { $rejected = $true }
    if (!$rejected) { throw "FAIL: $Name was accepted" }
    Write-Output "PASS: reject $Name"
    $script:passed++
}
$one = Read-MicHardware -Text $active -Profiles $profiles
if ($one.profile.profile_id -cne 'xeon-phi-3120a') { throw '3120A selection failed' }
Write-Output 'PASS: select 3120A profile'; $passed++
$captured = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures/micinfo-windows-3120a.txt') -Raw
$real = Read-MicHardware -Text $captured -Profiles $profiles
if ($real.profile.profile_id -cne 'xeon-phi-3120a' -or $real.temperature_c -ne 41 -or $real.gddr_mib -ne 5952) { throw 'Captured Windows telemetry parsing failed.' }
Write-Output 'PASS: parse captured Windows telemetry with tabs and CRLF'; $passed++
$passive = $active.Replace('3120/3140 P/A','7120P').Replace('Active CS','Passive CS').Replace('57','61').Replace('5952','15872').Replace('2700','0')
$two = Read-MicHardware -Text $passive -Profiles $profiles
if ($two.profile.profile_id -cne 'xeon-phi-7120p' -or $two.profile.cooling_type -cne 'forced-air') { throw '7120P selection failed' }
Write-Output 'PASS: select 7120P forced-air profile'; $passed++
Reject 'missing telemetry' $active.Replace('Die Temp : 53 C','Die Temp : N/A')
Reject 'high temperature' $active.Replace('53 C','75 C')
Reject 'zero temperature' $active.Replace('53 C','0 C')
Reject 'stopped active fan' $active.Replace('2700','0')
Reject 'passive board under active profile' $active.Replace('Active CS','Passive CS')
Reject 'wrong memory class' $active.Replace('5952','15872')
Reject 'conflicting SKU' $active.Replace('3120/3140 P/A','7120P')
Reject 'missing ECC state' $active.Replace('ECC Mode : Enabled','ECC Mode : N/A')
Reject 'multiple devices' ($active + "`nDevice No: 1, Device Name: mic1`n" + $active)
Write-Output "PASS: $passed hardware profile tests"
