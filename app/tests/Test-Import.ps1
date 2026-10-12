Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/ChatCore.ps1')
$temp=Join-Path ([IO.Path]::GetTempPath()) ('phi-import-'+[Guid]::NewGuid().ToString('N'))
$kit=Join-Path $temp 'kit'; $data=Join-Path $temp 'data'
$artifacts=Join-Path $kit 'artifacts'; $build=Join-Path $artifacts 'run-001'
$commit=(Read-JsonFile (Join-Path $root 'config/app.yaml')).source_commit
try {
    $null=New-Item -ItemType Directory -Path (Join-Path $build 'report') -Force
    $null=New-Item -ItemType Directory -Path $data
    Write-Utf8 (Join-Path $build 'report/exit-code.txt') 'exit_code=0'
    Write-Utf8 (Join-Path $build 'runtime.tar') 'fixture, not a binary'
    $state=[pscustomobject]@{source_commit=$commit;remote_base='/root/knc-phase3-run-001';runtime_archive=(Join-Path $build 'runtime.tar');evidence=$build}
    Write-JsonFile (Join-Path $artifacts 'last-build.json') $state
    $null=Import-Phase3Runtime $kit $data $commit
    if (!(Test-Path -LiteralPath (Join-Path $data 'baseline-phase3/run-001/runtime.tar'))) { throw 'Runtime backup missing' }
    if (Test-Path -LiteralPath (Join-Path $data 'accepted')) { throw 'Installer fabricated model approval' }
    Write-Output 'PASS: runtime imports without Smoke, Stability or model approval records'
    Write-Utf8 (Join-Path $data 'baseline-phase3/run-001/preserved.txt') 'keep'
    $null=Import-Phase3Runtime $kit $data $commit
    if ((Get-Content -LiteralPath (Join-Path $data 'baseline-phase3/run-001/preserved.txt')) -cne 'keep') { throw 'Reinstall damaged the backup' }
    Write-Output 'PASS: reinstall preserves existing backups'
    $failed=$false
    try { $null=Import-Phase3Runtime $kit $data ('f'*40) } catch { $failed=$true }
    if (!$failed) { throw 'Wrong source revision accepted' }
    Write-Output 'PASS: wrong runtime source revision rejected'
    Write-Utf8 (Join-Path $build 'report/exit-code.txt') 'exit_code=139'
    $failed=$false
    try { $null=Import-Phase3Runtime $kit $data $commit } catch { $failed=$true }
    if (!$failed) { throw 'Failed native build accepted' }
    Write-Output 'PASS: failed native build rejected'
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
