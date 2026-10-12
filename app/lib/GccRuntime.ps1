# A separate per-card runtime selection; never edits the Phase 3 build receipt.
function Get-GccSelectionPath([string]$Data,$Health) {
    if ($Health.serial -notmatch '^[A-Za-z0-9-]+$' -or $Health.profile.profile_id -notin @('xeon-phi-3120a','xeon-phi-7120p')) { throw 'Unsupported GCC runtime card identity.' }
    return Join-Path $Data ('gcc-runtime/active-'+$Health.serial+'.json')
}
function Get-GccPayload($Health) {
    $pin=Read-JsonFile (Join-Path $script:root 'config/gcc-runtime.json')
    if ($pin.version -cne '1.3.8' -or $pin.source_commit -cne $script:cfg.source_commit -or $pin.kernel_version -cne '0.2.1') { throw 'Invalid GCC runtime package pin.' }
    $variants=@($pin.payloads | Where-Object { $_.profile -ceq $Health.profile.profile_id })
    if ($variants.Count -ne 1) { throw 'No GCC kernel variant for the detected card.' }
    $p=$variants[0]
    if ($p.sha256 -notmatch '^[a-f0-9]{64}$' -or $p.file -notmatch '^runtime-(3120A|7120P)\.tar$' -or $p.runtime_id -notmatch '^phichat138-gcc021-[a-f0-9]{16}$' -or $p.bytes -lt 1024 -or $p.bytes -gt 100MB) { throw 'Invalid runtime payload identity.' }
    return $p
}
function Assert-GccPayload([string]$Path,$Payload) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Item -LiteralPath $Path).Length -ne $Payload.bytes -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Payload.sha256) { throw "GCC runtime archive is missing or changed: $Path" }
}
function Install-GccCardRuntime($Baseline,[string]$PackageDir='') {
    $payload=Get-GccPayload $script:health
    $store=Join-Path $script:data ('gcc-runtime/payload-'+$payload.sha256)
    $local=Join-Path $store $payload.file
    if ($PackageDir) {
        $incoming=Join-Path $PackageDir $payload.file
        Assert-GccPayload $incoming $payload
        $null=New-Item -ItemType Directory -Path $store -Force
        $repair=$false
        try { Assert-GccPayload $local $payload } catch { $repair=$true }
        if ($repair) { Copy-Item -LiteralPath $incoming -Destination $local -Force }
    }
    Assert-GccPayload $local $payload
    $id=[Guid]::NewGuid().ToString('N')
    $remote='/root/knc-phase3-run-gcc021-'+$id
    Assert-RemoteBase $Baseline.remote_base
    Acquire-CardWorkloadLock
    try {
        $memory=Read-MemorySnapshot (Invoke-Card 'cat /proc/meminfo')
        # Covers two archive-sized copies, extraction, tests and the reserve.
        $required=512MB+3*[long]$payload.bytes
        if ($memory.available_kib*1024 -lt $required) { throw 'Insufficient free GDDR for runtime installation; stop inference and free the model cache first.' }
        $null=Invoke-Card "test -x '$($Baseline.remote_base)/guard' && test `"`$(cat '$($Baseline.remote_base)/build-passed.txt')`" = '$($script:cfg.source_commit)' && mkdir '$remote'"
        Send-CardFiles @($local,(Join-Path $script:root 'scripts/gcc-runtime-install.sh'),(Join-Path $script:root 'scripts/elf-check.sh'),(Join-Path $script:root 'scripts/memory-info.awk')) ($remote+'/')
        # BusyBox builds vary in their hash applets. Read back the staged bytes
        # over the same verified SSH channel and hash them locally before use.
        $returned=Join-Path $script:job 'staged-runtime.tar'
        $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+@(($script:target+':'+$remote+'/'+$payload.file),$returned)) 180
        Assert-GccPayload $returned $payload
        Remove-Item -LiteralPath $returned
        $script:activity='Validating GNU IMCI runtime on the Xeon Phi; temperature and Stop protection remain active.'
        Set-JobStatus $script:activity
        $command="exec '$($Baseline.remote_base)/guard' 900 $($script:cfg.heartbeat_timeout_seconds) bash '$remote/gcc-runtime-install.sh' '$remote' '$($Baseline.remote_base)' '$($script:cardLockToken)' '$($payload.file)' '$($payload.runtime_id)' '$($script:cfg.source_commit)'"
        $null=Invoke-JobProcess $script:ssh ($script:sshOptions+@('-T',$script:target,$command)) 930 (Join-Path $script:job 'native-validation.txt') -Guarded
        $receipt=(Invoke-Card "cat '$remote/gcc-runtime-passed.txt'").Trim()
        if ($receipt -cne $payload.runtime_id) { throw 'Native runtime validation receipt is missing or mismatched.' }
        $null=Read-CardHealth
        $selection=[pscustomobject]@{schema_version=1;enabled=$true;version='1.3.8';kernel_version='0.2.1';source_commit=$script:cfg.source_commit;serial=$script:health.serial;profile=$script:health.profile.profile_id;remote_base=$remote;runtime_id=$payload.runtime_id;archive_sha256=$payload.sha256;evidence=$script:job;validation='native-kernels-numerics-and-cli-startup';created_utc=(Get-Date).ToUniversalTime().ToString('o')}
        $path=Get-GccSelectionPath $script:data $script:health
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $script:job 'previous-gcc-selection.json') }
        Write-JsonFile $path $selection
        return $selection
    } finally { Release-CardWorkloadLock }
}
function Resolve-GccRuntime($Baseline,[switch]$RestoreMissing) {
    $path=Get-GccSelectionPath $script:data $script:health
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { return $Baseline }
    $s=Read-JsonFile $path
    if (!$s.enabled) { return $Baseline }
    $payload=Get-GccPayload $script:health
    if ($s.schema_version -ne 1 -or $s.source_commit -cne $Baseline.source_commit -or $s.serial -cne $script:health.serial -or
        $s.profile -cne $script:health.profile.profile_id -or $s.archive_sha256 -cne $payload.sha256 -or $s.runtime_id -cne $payload.runtime_id -or
        $s.validation -cne 'native-kernels-numerics-and-cli-startup') { throw 'GCC runtime selection does not match this card/build. Reinstall the GCC runtime or roll back.' }
    Assert-RemoteBase $s.remote_base
    if ($RestoreMissing) {
        $present=(Invoke-Card "if test -x '$($s.remote_base)/llama/main' && test -f '$($s.remote_base)/gcc-runtime-passed.txt'; then cat '$($s.remote_base)/gcc-runtime-passed.txt'; fi").Trim()
        if ($present -cne $payload.runtime_id) { $s=Install-GccCardRuntime $Baseline }
    }
    $result=$Baseline | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $result.remote_base=$s.remote_base
    $result | Add-Member -NotePropertyName gcc_runtime_id -NotePropertyValue $s.runtime_id -Force
    return $result
}
function Disable-GccRuntime {
    $path=Get-GccSelectionPath $script:data $script:health
    Acquire-CardWorkloadLock
    try {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $s=Read-JsonFile $path
            Copy-Item -LiteralPath $path -Destination (Join-Path $script:job 'previous-gcc-selection.json')
            $s.enabled=$false
            Write-JsonFile $path $s
        }
    } finally { Release-CardWorkloadLock }
}
