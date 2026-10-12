#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/Preparation.ps1')
$script:cfg=[pscustomobject]@{poll_seconds=5}
$script:health=[pscustomobject]@{temperature_c=41;sampled_utc=[DateTime]::UtcNow.ToString('o');profile=[pscustomobject]@{thermal_warn_c=75}}
$script:reads=0
function Read-CardHealth { $script:reads++ }
Update-PreparationHealth
if ($script:reads -ne 0) { throw 'Fresh safe telemetry was not reused' }
$script:health.temperature_c=76
Update-PreparationHealth
if ($script:reads -ne 1) { throw 'Warm telemetry skipped pre-inference gate' }
$script:health.temperature_c=41
$script:health.sampled_utc=[DateTime]::UtcNow.AddSeconds(-10).ToString('o')
Update-PreparationHealth
if ($script:reads -ne 2) { throw 'Stale telemetry skipped refresh' }
Write-Output 'PASS: preparation reuses safe recent telemetry; warm/stale samples require strict health refresh'
