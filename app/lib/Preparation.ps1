function Update-PreparationHealth {
    # Preserve the stricter pre-inference start gate. Only an eligible, recent
    # sample can be reused; ongoing-work telemetry may have allowed warmer values.
    if (!$script:health -or !$script:health.PSObject.Properties['sampled_utc'] -or
        ([DateTime]::UtcNow-[DateTimeOffset]::Parse([string]$script:health.sampled_utc).UtcDateTime).TotalSeconds -ge [int]$script:cfg.poll_seconds -or
        $script:health.temperature_c -ge $script:health.profile.thermal_warn_c) {
        $null=Read-CardHealth
    }
}
# Small metadata checks are combined; model bytes are never scanned during Send.
function Set-ScpCompatibility {
    $info=Get-Item -LiteralPath $script:ssh
    $key=$info.FullName+'|'+$info.Length+'|'+$info.LastWriteTimeUtc.Ticks
    $file=Join-Path $script:data 'ssh-client.json'
    $cached=$null
    if (Test-Path -LiteralPath $file) { try { $cached=Read-JsonFile $file } catch {} }
    if ($cached -and $cached.PSObject.Properties['key'] -and $cached.key -ceq $key -and $cached.PSObject.Properties['legacy_scp']) {
        [string[]]$script:scpMode=@(if ($cached.legacy_scp) { '-O' })
        return
    }
    $null=Invoke-JobProcess $script:ssh @('-V')
    $version=Get-Content -LiteralPath (Join-Path $script:job ('process-'+$script:processIndex.ToString('D4')+'.stderr.txt')) -Raw
    if ($version -notmatch 'OpenSSH(?:_for_Windows)?_(\d+)\.') { throw 'Cannot determine OpenSSH file-transfer compatibility.' }
    $legacy=([int]$Matches[1] -ge 9)
    [string[]]$script:scpMode=@(if ($legacy) { '-O' })
    Write-JsonFile $file ([pscustomobject]@{key=$key;legacy_scp=$legacy})
}
function Prepare-ChatSession($Ready,$Model,$State) {
    Assert-ModelReady $Ready $Model $State $script:health
    $script:cardLockToken=[Guid]::NewGuid().ToString('N')
    $script:cardLockOwned=$true; $script:cleanupConfirmed=$false
    $script:preparedRemote='/root/knc-chat-'+[Guid]::NewGuid().ToString('N')
    $base=$State.remote_base; $remote=$Ready.remote_model
    $exe=if (Test-ModernTextModel $Model) { 'phi-modern' } else { 'main' }
    $identity="test `"`$(cat '$remote.identity' 2>/dev/null)`" = '$($Model.sha256)'"
    if ($remote -ceq "$base/model.gguf") { $identity='true' }
    # No prompt text appears in this command or its evidence. Architecture,
    # runtime, lock, model metadata, boot identity and memory share one SSH call.
    $command=@"
# PHICHAT_PREPARE_V1
set -eu
[ "`$(uname -m)" = k1om ] || { echo 'SSH target is not K1OM; inference stopped.' >&2; exit 1; }
[ -x '$base/guard' ] && [ -x '$base/llama/$exe' ] && [ "`$(cat '$base/build-passed.txt' 2>/dev/null)" = '$($script:cfg.source_commit)' ] || { echo 'Accepted runtime is absent on the card. Click Restore runtime, then Connect again.' >&2; exit 1; }
if mkdir /tmp/knc-phase3-workload.lock 2>/dev/null; then printf '%s\n' '$($script:cardLockToken)' > /tmp/knc-phase3-workload.lock/phi-chat-owner; else echo 'Another workload or retained lock exists; stop that workload before switching models.' >&2; exit 1; fi
[ -f '$remote' ] && [ "`$(LC_ALL=C ls -ln '$remote' | awk '{print `$5}')" = '$($Model.file_size_bytes)' ] && $identity || { echo 'The selected model is no longer ready on the Phi. Click Load model again.' >&2; exit 1; }
mkdir '$($script:preparedRemote)'
printf 'BOOT\t'; if [ -r /proc/sys/kernel/random/boot_id ]; then cat /proc/sys/kernel/random/boot_id; else printf '\n'; fi
printf 'MODEL\t'; LC_ALL=C ls -ln '$remote'
printf 'MAIN\t'; LC_ALL=C ls -ln '$base/llama/$exe'
printf 'MEMORY\n'; cat /proc/meminfo
"@
    try {
        $raw=Invoke-Card $command
        $m=[regex]::Match($raw.Replace("`r`n","`n"),'\ABOOT\t([^\n]*)\nMODEL\t([^\n]+)\nMAIN\t([^\n]+)\nMEMORY\n([\s\S]+)\z')
        if (!$m.Success) { throw 'Incomplete native preparation metadata; no inference started.' }
        $script:sessionMetadata=[pscustomobject]@{boot=$m.Groups[1].Value;model=$m.Groups[2].Value;main=$m.Groups[3].Value}
        $script:preparedMemory=$m.Groups[4].Value
        Write-Utf8 (Join-Path $script:job 'preparation-metadata.txt') $raw
        return $remote
    } catch { Release-CardWorkloadLock; throw }
}
function Get-AllocationKey($Model,$State,$Threads) {
    if (!$script:sessionMetadata -or $script:sessionMetadata.boot -notmatch '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$') { return '' }
    return (ConvertTo-Json -Compress -InputObject ([ordered]@{
        version='1.3.6';boot=$script:sessionMetadata.boot;serial=$script:health.serial
        model=$Model.sha256;model_metadata=$script:sessionMetadata.model;main_metadata=$script:sessionMetadata.main
        runtime=$State.remote_base;source=$State.source_commit;profile=$script:health.profile.profile_id
        context=$Model.context_tokens;batch=$script:request.batch;threads=$Threads.generation;prompt_threads=$Threads.prompt
        runtime_mib=$Model.estimated_peak_runtime_mib;budget=$script:health.profile.safe_memory_budget_mib;reserve=$script:health.profile.available_reserve_mib
    }))
}
function Test-AllocationReceipt([string]$Key) {
    if (!$Key) { return $false }
    $file=Join-Path $script:data 'context-allocation.json'
    if (!(Test-Path -LiteralPath $file)) { return $false }
    try {
        $saved=Read-JsonFile $file
        return ($saved.key -ceq $Key -and $saved.measured_samples -gt 0)
    } catch { return $false }
}
function Save-AllocationReceipt([string]$Key,$Check) {
    if ($Key -and $Check.memory_samples -gt 0) {
        Write-JsonFile (Join-Path $script:data 'context-allocation.json') ([pscustomobject]@{key=$Key;measured_samples=$Check.memory_samples;validated_utc=[DateTime]::UtcNow.ToString('o');evidence_job=$script:job})
    }
}
