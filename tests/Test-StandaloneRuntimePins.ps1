#Requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$AppRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:root=$AppRoot
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/ModernRuntime.ps1')
$script:cfg=Read-JsonFile (Join-Path $AppRoot 'config/app.yaml')
$pin=Read-JsonFile (Join-Path $AppRoot 'config/modern-runtime.json')
foreach ($payload in $pin.payloads) {
    $health=[pscustomobject]@{profile=[pscustomobject]@{profile_id=$payload.profile}}
    $found=Get-ModernPayload $health '1.4.2' $payload.runtime_id
    if ($found.sha256 -cne $payload.sha256) { throw 'Saved runtime ID resolved to a different archive.' }
    $wrong=@($pin.payloads | Where-Object { $_.profile -cne $payload.profile })[0]
    $failed=$false
    try { $null=Get-ModernPayload $health '1.4.2' $wrong.runtime_id } catch { $failed=$true }
    if (!$failed) { throw 'Runtime from a different card profile was accepted.' }
    Write-Output ('PASS: exact runtime ID/SHA for '+$payload.profile+'; wrong-profile runtime rejected.')
}
$previous=Read-JsonFile (Join-Path $AppRoot 'config/modern-runtime-1.5.3-paired.json')
foreach ($payload in $previous.payloads) {
    $health=[pscustomobject]@{profile=[pscustomobject]@{profile_id=$payload.profile}}
    $found=Get-ModernPayload $health '1.4.2' $payload.runtime_id
    if ($found.sha256 -cne $payload.sha256) { throw 'Previous paired runtime pin was lost.' }
    Write-Output ('PASS: original 1.5.3 runtime still resolves by exact ID for '+$payload.profile)
}
