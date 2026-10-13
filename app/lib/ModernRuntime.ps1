. (Join-Path $PSScriptRoot 'RuntimeGuard.ps1')
# A separate per-card runtime selection; never edits the Phase 3 build receipt.
function Get-ModernSelectionPath([string]$Data,$Health) {
    if ($Health.serial -notmatch '^[A-Za-z0-9-]+$' -or $Health.profile.profile_id -notin @('xeon-phi-3120a','xeon-phi-7120p')) { throw 'Unsupported modern text runtime card identity.' }
    return Join-Path $Data ('modern-runtime/active-'+$Health.serial+'.json')
}
# 1.4.3.3: version 1.4.2 has two different pinned native builds. Resolve
# saved selections by runtime ID, including restore after reboot and rollback.
function Get-ModernPayload($Health,[string]$Version='1.4.2',[string]$RuntimeId='') {
    if ($Version -notin @('1.4.0','1.4.1','1.4.2')) { throw 'Unsupported modern runtime version.' }
    $files=if ($Version -cne '1.4.2') { @('config/modern-runtime-'+$Version+'.json') }
           elseif ($RuntimeId) { @('config/modern-runtime.json','config/modern-runtime-1.5.3-paired.json','config/modern-runtime-1.4.2-original.json','config/modern-runtime-q5-repair-r1.json','config/modern-runtime-preview-standard.json') }
           else { @('config/modern-runtime.json') }
    $matches=@(foreach ($file in $files) {
        $pin=Read-JsonFile (Join-Path $script:root $file)
        if ($pin.version -cne $Version -or $pin.source_commit -cne $script:cfg.source_commit -or $pin.kernel_version -cne '0.2.1' -or $pin.modern_source_commit -cne '6783b11fb0889d68d0046176b4cc92ceee1961b0') { throw 'Invalid modern text runtime package pin.' }
        $variants=@($pin.payloads | Where-Object { $_.profile -ceq $Health.profile.profile_id })
        if ($RuntimeId -and $variants.Count -eq 0) { continue }
        if ($variants.Count -ne 1) { throw 'No modern text kernel variant for the detected card.' }
        $p=$variants[0]
        if ($p.sha256 -notmatch '^[a-f0-9]{64}$' -or $p.file -notmatch '^runtime-(3120A|7120P)\.tar$' -or $p.runtime_id -notmatch '^phichat14[012]-modern-[a-f0-9]{16}$' -or $p.bytes -lt 1024 -or $p.bytes -gt 100MB) { throw 'Invalid runtime payload identity.' }
        if (!$RuntimeId -or $p.runtime_id -ceq $RuntimeId) { $p }
    })
    if ($matches.Count -ne 1) { throw 'Unknown or ambiguous native runtime identity; preserve the selection and restore the matching package pin.' }
    return $matches[0]
}
function Assert-ModernSelection($Selection,$Payload) {
    if ($Selection.schema_version -ne 1 -or $Selection.source_commit -cne $script:cfg.source_commit -or
        $Selection.kernel_version -cne '0.2.1' -or $Selection.serial -cne $script:health.serial -or
        $Selection.profile -cne $script:health.profile.profile_id -or $Selection.archive_sha256 -cne $Payload.sha256 -or
        $Selection.runtime_id -cne $Payload.runtime_id -or $Selection.validation -cne 'native-kernels-dispatch-and-cli-startup') {
        throw 'Modern runtime selection does not match this card/build. Preserve evidence and restore the matching runtime.'
    }
    Assert-RemoteBase $Selection.remote_base
}
function Assert-ModernPayload([string]$Path,$Payload) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -ne $Payload.bytes -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Payload.sha256) { throw "Modern runtime cache is missing or changed: $Path. Restore this exact archive from its matching package. Run Setup.cmd from the matching installer ZIP to repair its runtime cache." }
}
function Install-ModernCardRuntime($Baseline,[string]$PackageDir='',[string]$Version='1.4.2',[string]$RuntimeId='') {
    $payload=Get-ModernPayload $script:health $Version $RuntimeId
    $store=Join-Path $script:data ('modern-runtime/payload-'+$payload.sha256)
    $local=Join-Path $store $payload.file
    if ($PackageDir) {
        $incoming=Join-Path $PackageDir $payload.file
        Assert-ModernPayload $incoming $payload
        $null=New-Item -ItemType Directory -Path $store -Force
        $repair=$false
        try { Assert-ModernPayload $local $payload } catch { $repair=$true }
        if ($repair) { Copy-Item -LiteralPath $incoming -Destination $local -Force }
    }
    Assert-ModernPayload $local $payload
    $id=[Guid]::NewGuid().ToString('N')
    $remote='/root/knc-phase3-run-modern'+$Version.Replace('.','')+'-'+$id
    Assert-RemoteBase $Baseline.remote_base
    Acquire-CardWorkloadLock
    try {
        $memory=Read-MemorySnapshot (Invoke-Card 'cat /proc/meminfo')
        # Covers two archive-sized copies, extraction, tests and the reserve.
        $required=512MB+3*[long]$payload.bytes
        if ($memory.available_kib*1024 -lt $required) { throw 'Insufficient free GDDR for runtime installation; stop inference and free the model cache first.' }
        $null=Invoke-Card "mkdir '$remote'"
        Install-RuntimeGuard $Baseline $remote
        $script:activity='Uploading the prebuilt runtime and verifying staged bytes.'
        Set-JobStatus $script:activity
        Send-CardFiles @($local,(Join-Path $script:root 'scripts/modern-runtime-install.sh'),(Join-Path $script:root 'scripts/elf-check.sh'),(Join-Path $script:root 'scripts/memory-info.awk')) ($remote+'/')
        # BusyBox builds vary in their hash applets. Read back the staged bytes
        # over the same verified SSH channel and hash them locally before use.
        $returned=Join-Path $script:job 'staged-runtime.tar'
        $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+@(($script:target+':'+$remote+'/'+$payload.file),$returned)) 180
        Assert-ModernPayload $returned $payload
        Remove-Item -LiteralPath $returned
        $script:activity='Validating GNU IMCI runtime on the Xeon Phi; temperature and Stop protection remain active.'
        Set-JobStatus $script:activity
        $command="exec '$remote/guard' 900 $($script:cfg.heartbeat_timeout_seconds) bash '$remote/modern-runtime-install.sh' '$remote' '$remote' '$($script:cardLockToken)' '$($payload.file)' '$($payload.runtime_id)' '$($script:cfg.source_commit)'"
        $null=Invoke-JobProcess $script:ssh ($script:sshOptions+@('-T',$script:target,$command)) 930 (Join-Path $script:job 'native-validation.txt') -Guarded
        $receipt=(Invoke-Card "cat '$remote/modern-runtime-passed.txt'").Trim()
        if ($receipt -cne $payload.runtime_id) { throw 'Native runtime validation receipt is missing or mismatched.' }
        $null=Read-CardHealth
        $selection=[pscustomobject]@{schema_version=1;enabled=$true;version=$Version;kernel_version='0.2.1';source_commit=$script:cfg.source_commit;serial=$script:health.serial;profile=$script:health.profile.profile_id;remote_base=$remote;runtime_id=$payload.runtime_id;archive_sha256=$payload.sha256;evidence=$script:job;validation='native-kernels-dispatch-and-cli-startup';created_utc=(Get-Date).ToUniversalTime().ToString('o')}
        $path=Get-ModernSelectionPath $script:data $script:health
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $script:job 'previous-modern-selection.json') }
        if (Test-Path -LiteralPath $path) {
            $previous=Read-JsonFile $path
            if ($previous.runtime_id -cne $selection.runtime_id) { Copy-Item -LiteralPath $path -Destination ($path+'.previous.json') -Force }
        }
        Write-JsonFile $path $selection
        return $selection
    } finally { Release-CardWorkloadLock }
}
function Resolve-ModernRuntime($Baseline,[switch]$RestoreMissing) {
    $path=Get-ModernSelectionPath $script:data $script:health
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { return $Baseline }
    $s=Read-JsonFile $path
    if (!$s.enabled) { return $Baseline }
    $payload=Get-ModernPayload $script:health ([string]$s.version) ([string]$s.runtime_id)
    Assert-ModernSelection $s $payload
    if ($s.source_commit -cne $Baseline.source_commit) { throw 'Baseline source differs from modern runtime.' }
    if ($RestoreMissing) {
        $engine=if ($payload.PSObject.Properties['features'] -and 'shared-multi-quant-v1' -cin $payload.features) { 'shared/bin/phi-modern' } else { 'llama/main' }
        $present=(Invoke-Card "if test -x '$($s.remote_base)/$engine' && test -f '$($s.remote_base)/modern-runtime-passed.txt'; then cat '$($s.remote_base)/modern-runtime-passed.txt'; fi").Trim()
        if ($present -cne $payload.runtime_id) { $s=Install-ModernCardRuntime $Baseline -Version ([string]$s.version) -RuntimeId ([string]$s.runtime_id) }
    }
    $result=$Baseline | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $result.remote_base=$s.remote_base
    $result | Add-Member -NotePropertyName modern_runtime_version -NotePropertyValue $s.version -Force
    $result | Add-Member -NotePropertyName modern_runtime_id -NotePropertyValue $s.runtime_id -Force
    $result | Add-Member -NotePropertyName modern_features -NotePropertyValue @($(if ($payload.PSObject.Properties['features']) {$payload.features})) -Force
    $result | Add-Member -NotePropertyName modern_source_commit -NotePropertyValue '6783b11fb0889d68d0046176b4cc92ceee1961b0' -Force
    return $result
}
function Disable-ModernRuntime {
    $path=Get-ModernSelectionPath $script:data $script:health
    Acquire-CardWorkloadLock
    try {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $s=Read-JsonFile $path
            Copy-Item -LiteralPath $path -Destination (Join-Path $script:job 'previous-modern-selection.json')
            if (Test-Path -LiteralPath ($path+'.previous.json')) {
                $previous=Read-JsonFile ($path+'.previous.json')
                $previousPayload=Get-ModernPayload $script:health ([string]$previous.version) ([string]$previous.runtime_id)
                Assert-ModernSelection $previous $previousPayload
                Write-JsonFile $path $previous
                Remove-Item -LiteralPath ($path+'.previous.json')
            } else { $s.enabled=$false; Write-JsonFile $path $s }
        }
    } finally { Release-CardWorkloadLock }
}
