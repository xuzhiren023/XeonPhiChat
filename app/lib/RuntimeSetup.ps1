# Keep the proven native runtime. Chat does not depend on model approval records.
function Import-Phase3Runtime([string]$Kit,[string]$Data,[string]$Commit) {
    $statePath=Join-Path $Kit 'artifacts/last-build.json'
    $state=Read-JsonFile $statePath
    Assert-RemoteBase $state.remote_base
    if ($state.source_commit -cne $Commit) { throw 'Saved runtime uses a different source revision.' }
    if (!(Test-Path -LiteralPath $state.runtime_archive -PathType Leaf)) { throw 'Saved runtime.tar is missing. Restore the Windows runtime backup first.' }
    if ((Get-Content -LiteralPath (Join-Path $state.evidence 'report/exit-code.txt') -Raw).Trim() -cne 'exit_code=0') { throw 'Saved Build did not complete successfully.' }
    $backup=Join-Path $Data ('baseline-phase3/'+(Split-Path $state.evidence -Leaf))
    # Fresh installs preserve the existing build evidence. Reinstalling is idempotent.
    if (!(Test-Path -LiteralPath $backup)) {
        $null=New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force
        Copy-Item -LiteralPath $state.evidence -Destination $backup -Recurse
    }
    if (!(Test-Path -LiteralPath (Join-Path $backup 'runtime.tar'))) {
        Copy-Item -LiteralPath $state.runtime_archive -Destination (Join-Path $backup 'runtime.tar')
    }
    Write-JsonFile (Join-Path $Data 'runtime-import.json') ([pscustomobject]@{source_commit=$Commit;source_state=$statePath;backup=$backup;created_utc=(Get-Date).ToUniversalTime().ToString('o')})
    return $state
}
