# Linux/PowerShell test harness uses tiny fixture processes, never inference.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:root=Split-Path $PSScriptRoot -Parent
. (Join-Path $script:root 'lib/ChatCore.ps1')
. (Join-Path $script:root 'lib/Transport.ps1')
if (!(Test-Path -LiteralPath '/bin/bash')) { Write-Output 'SKIP: process harness requires /bin/bash; core tests run on Windows.'; exit 0 }
$script:job=Join-Path ([IO.Path]::GetTempPath()) ('phi-transport-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $script:job
$script:health=$null; $script:processIndex=0; $script:cleanupMode=$false
$script:request=[pscustomobject]@{owner_pid=0}
$script:cfg=[pscustomobject]@{poll_seconds=1}
$script:activity='fixture'; $script:thermalReads=0
function Read-CardHealth { param([switch]$DuringRun); $script:thermalReads++; return $null }
try {
    $script:health=[pscustomobject]@{sampled_utc=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(-4)).ToString('o')}
    Update-LoadTemperature
    if ($script:thermalReads -ne 0) { throw 'Recent temperature sample was treated as stale across timezones.' }
    $script:health.sampled_utc=[DateTimeOffset]::UtcNow.AddSeconds(-30).ToString('o')
    Update-LoadTemperature
    if ($script:thermalReads -ne 1) { throw 'Stale temperature sample was reused.' }
    $script:health=$null
    Write-Output 'PASS: temperature polling compares UTC timestamps across host timezones'
    $v=Invoke-JobProcess '/bin/bash' @('-c','printf output; printf error >&2') 5
    if ($v -cne 'output') { throw 'stdout lost' }
    if ((Get-Content -LiteralPath (Join-Path $script:job 'process-0001.stderr.txt') -Raw) -cne 'error') { throw 'stderr lost' }
    Write-Output 'PASS: stdout/stderr drain independently'
    $out=Join-Path $script:job 'response.txt'
    $script:streamFixturePath=$out
    $script:sawPartial=$false
    $observe={ param([double]$ElapsedSeconds)
        if ((Test-Path -LiteralPath $script:streamFixturePath) -and [IO.File]::ReadAllText($script:streamFixturePath) -ceq 'first') { $script:sawPartial=$true }
    }
    $null=Invoke-JobProcess '/bin/bash' @('-c','read -r line; printf first; sleep 2; printf second') 5 $out -Guarded -OnTick $observe
    if (!$script:sawPartial) { throw 'Short text was buffered until process completion.' }
    if ((Get-Content -LiteralPath $out -Raw) -cne 'firstsecond') { throw 'stream incomplete' }
    $metrics=Read-JsonFile (Join-Path $script:job 'response-stream.json')
    if ($null -eq $metrics.first_byte_seconds -or $metrics.first_byte_seconds -ge 1.5 -or $metrics.bytes -ne 11) { throw 'First-stream-byte timing missing or incorrect.' }
    Write-Output 'PASS: partial short reply visible before process completion, with first-byte timing'
    $script:sawLive=$false
    $observeLive={ param([double]$ElapsedSeconds)
        $livePath=Join-Path $script:job 'live-progress.json'
        if (Test-Path -LiteralPath $livePath) {
            $live=Read-JsonFile $livePath
            if (!$live.complete -and $null -ne $live.native -and $live.native.Consumed -eq 64) { $script:sawLive=$true }
        }
    }
    $null=Invoke-JobProcess '/bin/bash' @('-c','read -r line; printf "PHICHAT_PROGRESS prefill 64 2000000 400000\n" >&2; sleep 3; printf answer; printf "real diagnostic\n" >&2') 8 $out -Guarded -OnTick $observeLive
    if (!$script:sawLive) { throw 'Native counters were not visible before completion.' }
    $live=Read-JsonFile (Join-Path $script:job 'live-progress.json')
    if (!$live.complete -or $live.native.AvailableKiB -ne 2000000 -or $live.output_bytes -ne 6) { throw 'Native/output counter disagreement.' }
    $stderr=[IO.File]::ReadAllText((Join-Path $script:job 'process-0003.stderr.txt'))
    if ($stderr -notmatch 'real diagnostic' -or $stderr -match 'PHICHAT_PROGRESS') { throw 'Diagnostics lost or control records mixed with errors.' }
    Write-Output 'PASS: asynchronous native stage/token/memory counters published before exit; real stderr retained'
    $tail=New-Object PhiChat.Utf8Tail
    $utf8=Join-Path $script:job 'utf8.txt'
    [IO.File]::WriteAllBytes($utf8,[byte[]]@(65,240,159))
    if ($tail.Read($utf8,$false) -cne 'A') { throw 'Incomplete UTF-8 character was displayed.' }
    $append=[IO.File]::Open($utf8,[IO.FileMode]::Append)
    try { $append.Write([byte[]]@(152,128,90),0,3) } finally { $append.Dispose() }
    if ($tail.Read($utf8,$true) -cne ([char]::ConvertFromUtf32(128512)+'Z') -or $tail.Read($utf8,$true)) { throw 'UTF-8 streaming lost/duplicated characters.' }
    Write-Output 'PASS: split UTF-8 character preserved across live reads'
    $failed=$false
    try { $null=Invoke-JobProcess '/bin/bash' @('-c','exit 7') 5 } catch { $failed=$true }
    if (!$failed) { throw 'nonzero exit accepted' }
    Write-Output 'PASS: process failure cannot pass acceptance'
    $failed=$false
    try { $null=Invoke-JobProcess '/bin/bash' @('-c','sleep 3') 1 } catch { $failed=$true }
    if (!$failed) { throw 'timeout ignored' }
    Write-Output 'PASS: wall timeout enforced'
    Write-Utf8 (Join-Path $script:job 'cancel') 'stop'
    $failed=$false
    try { $null=Invoke-JobProcess '/bin/bash' @('-c','echo should-not-start') 5 } catch { $failed=$true }
    if (!$failed) { throw 'cancellation ignored' }
    $script:cleanupMode=$true
    $v=Invoke-JobProcess '/bin/bash' @('-c','printf cleanup') 5
    if ($v -cne 'cleanup') { throw 'cancel prevented bounded cleanup' }
    Write-Output 'PASS: cancellation blocks work but permits bounded cleanup'
} finally { Remove-Item -LiteralPath $script:job -Recurse -Force }
