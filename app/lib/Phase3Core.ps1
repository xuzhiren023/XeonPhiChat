# Helpers use Windows PowerShell 5.1-compatible APIs.
function Get-PhiFileHash([string]$LiteralPath,[string]$Algorithm='SHA256') {
    if ($Algorithm -cne 'SHA256') { throw 'Only SHA256 is supported for application assets.' }
    $hash=[Security.Cryptography.SHA256]::Create()
    $stream=$null
    try {
        $stream=[IO.File]::OpenRead($LiteralPath)
        return [pscustomobject]@{Hash=[BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','');Algorithm='SHA256';Path=$LiteralPath}
    } finally { if ($stream) { $stream.Dispose() }; $hash.Dispose() }
}

function Get-BuildPolicy {
    param([int]$RequestedJobs, $Config, $Profile)
    if ($RequestedJobs -lt 0 -or $RequestedJobs -gt 8 -or
        $Config.build_jobs -lt 0 -or $Config.build_jobs -gt 8 -or
        $Profile.build_jobs_max -lt 1 -or $Profile.build_jobs_max -gt 8 -or
        $Profile.build_jobs_default -lt 1 -or $Profile.build_jobs_default -gt $Profile.build_jobs_max) {
        throw 'Invalid bounded build-job configuration.'
    }
    $jobs = $RequestedJobs
    if ($jobs -eq 0) { $jobs = [int]$Config.build_jobs }
    if ($jobs -eq 0) { $jobs = [int]$Profile.build_jobs_default }
    if ($jobs -gt $Profile.build_jobs_max) { throw "Build jobs exceed this card's configured limit ($($Profile.build_jobs_max))." }
    if ($Config.build_job_memory_mib -lt 768 -or $Config.build_job_memory_mib -gt 4096 -or
        $Config.build_reserve_mib -lt 768 -or $Config.build_reserve_mib -gt 4096 -or
        $Config.build_stop_free_mib -lt 384 -or $Config.build_stop_free_mib -ge $Config.build_reserve_mib) {
        throw 'Invalid build-memory estimates or stop threshold.'
    }
    return [pscustomobject]@{
        jobs=$jobs; max_jobs=[int]$Profile.build_jobs_max
        job_memory_mib=[int]$Config.build_job_memory_mib
        reserve_mib=[int]$Config.build_reserve_mib
        stop_free_mib=[int]$Config.build_stop_free_mib
    }
}

function Write-Utf8([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
}
function Join-NativeArguments([string[]]$Values) {
    $parts = foreach ($value in $Values) {
        '"' + [regex]::Replace([regex]::Replace($value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
    }
    return ($parts -join ' ')
}
function Assert-NativeExit([string]$Action) {
    if ($LASTEXITCODE -ne 0) { throw "$Action failed (exit $LASTEXITCODE). Evidence retained." }
}
function Assert-ModelBudget($Model, $Profile) {
    if ($Model.PSObject.Properties['target_profiles'] -and $Profile.profile_id -cnotin @($Model.target_profiles)) {
        throw 'This model is not qualified for the connected card profile.'
    }
    if ($Model.context_tokens -lt 128) { throw 'Invalid model context allocation.' }
    if (!$Model.PSObject.Properties['memory_mode'] -or $Model.memory_mode -cne 'shared_mmap') {
        throw 'Model profile must declare shared_mmap accounting; old copy-mode estimates cannot be reused silently.'
    }
    if ($null -eq $Model.minimum_memory_mib -or [int]$Model.minimum_memory_mib -le 0 -or
        $Model.minimum_memory_mib -gt $Profile.safe_memory_budget_mib -or
        $Model.minimum_memory_mib -gt ($Profile.gddr_min_mib - $Profile.os_reserve_mib)) {
        throw 'Model minimum memory exceeds this card safe budget, or its budget is undeclared.'
    }
    if ($Model.estimated_peak_runtime_mib -le 0 -or
        ($Model.estimated_peak_runtime_mib + [math]::Ceiling($Model.file_size_bytes / 1MB) + $(if ($Model.PSObject.Properties['extra_resident_mib']) {$Model.extra_resident_mib} else {0})) -gt $Model.minimum_memory_mib) {
        throw 'Model budget does not cover the runtime and RAM-backed model file.'
    }
}
function Find-Phase2Run([string]$ProjectDir) {
    $roots = @(Get-ChildItem -LiteralPath $ProjectDir -Directory -Filter 'knc-native-probe-*' |
        ForEach-Object { Join-Path $_.FullName 'work\phase2-smoke' })
    $runs = @($roots | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
        Get-ChildItem -LiteralPath $_ -Directory -Filter 'run-*'
    } | Sort-Object Name -Descending)
    foreach ($run in $runs) {
        $exitFile = Join-Path $run.FullName 'report\exit-code.txt'
        $after = Join-Path $run.FullName 'hardware-after.json'
        if ((Test-Path -LiteralPath $exitFile) -and (Test-Path -LiteralPath $after)) {
            if ((Get-Content -LiteralPath $exitFile -Raw).Trim() -ceq 'exit_code=0') { return $run.FullName }
        }
    }
    throw 'No successful Phase 2 run found. Supply -Phase2Run with its Windows directory, or rerun the validated Phase 2 kit.'
}
function Assert-ModelFile([string]$Path, $Model, [string]$ReceiptPath) {
    $file = Get-Item -LiteralPath $Path
    if ($file.Length -ne $Model.file_size_bytes) { throw "Model size mismatch: $Path" }
    # One model identity check on admission. Reuse the receipt while the file
    # path, size, modification time and pinned expected digest remain the same.
    $receipt = $null
    if (Test-Path -LiteralPath $ReceiptPath) { try { $receipt = Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json } catch { $receipt=$null } }
    if ($receipt) {
        foreach ($field in @('path','bytes','modified_ticks','sha256')) {
            if (!$receipt.PSObject.Properties[$field]) { $receipt=$null; break }
        }
    }
    if ($null -ne $receipt -and $receipt.path -ceq $file.FullName -and $receipt.bytes -eq $file.Length -and
        $receipt.modified_ticks -eq $file.LastWriteTimeUtc.Ticks -and $receipt.sha256 -ceq $Model.sha256) {
        Write-Host 'Model identity receipt reused.'
        return
    }
    $stream = [IO.File]::OpenRead($Path)
    try {
        $magic = New-Object byte[] 4
        if ($stream.Read($magic, 0, 4) -ne 4 -or [Text.Encoding]::ASCII.GetString($magic) -cne 'GGUF') { throw 'Model is not a GGUF file.' }
    } finally { $stream.Dispose() }
    Write-Host 'Verifying model SHA-256 before chat; unchanged files reuse this result.'
    $digest = (Get-PhiFileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($digest -cne $Model.sha256) { throw 'Model does not match the pinned SHA-256.' }
    $after=Get-Item -LiteralPath $file.FullName
    if ($after.Length -ne $file.Length -or $after.LastWriteTimeUtc.Ticks -ne $file.LastWriteTimeUtc.Ticks) { throw 'Model changed during verification; retry Load model.' }
    $value = [pscustomobject]@{ path=$file.FullName; bytes=$file.Length; modified_ticks=$file.LastWriteTimeUtc.Ticks; sha256=$digest }
    Write-Utf8 $ReceiptPath ($value | ConvertTo-Json)
}
function Invoke-GuardedRemote {
    param([string]$SshPath, [string[]]$SshArguments, [string]$Prefix,
          [scriptblock]$HealthCheck, [int]$PollSeconds=5, [int]$WallSeconds=7200)
    $p = New-Object Diagnostics.Process
    $p.StartInfo.FileName = $SshPath
    $p.StartInfo.Arguments = Join-NativeArguments $SshArguments
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.CreateNoWindow = $true
    $p.StartInfo.RedirectStandardInput = $true
    $p.StartInfo.RedirectStandardOutput = $true
    $p.StartInfo.RedirectStandardError = $true
    $out = $null; $err = $null; $failure = ''; $code = $null; $started = $false
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $started = $p.Start()
        if (!$started) { throw 'SSH process did not start.' }
        $out = $p.StandardOutput.ReadToEndAsync()
        $err = $p.StandardError.ReadToEndAsync()
        $p.StandardInput.WriteLine('health-ok'); $p.StandardInput.Flush()
        while (!$p.WaitForExit($PollSeconds * 1000)) {
            if ($watch.Elapsed.TotalSeconds -gt ($WallSeconds + 30)) { throw 'Host wall-clock limit exceeded.' }
            & $HealthCheck
            if (!$p.HasExited) { $p.StandardInput.WriteLine('health-ok'); $p.StandardInput.Flush() }
        }
        $code = $p.ExitCode
    } catch { $failure = $_.Exception.Message }
    finally {
        if ($started) {
            try { $p.StandardInput.Close() } catch {}
            try {
                if (!$p.HasExited -and !$p.WaitForExit(10000)) { $p.Kill(); $null = $p.WaitForExit(5000) }
                if ($p.HasExited) { $code = $p.ExitCode }
            } catch { $failure += " Stop: $($_.Exception.Message)" }
        }
        if ($null -ne $out -and $out.Wait(5000)) { Write-Utf8 ($Prefix + '.stdout.txt') $out.Result }
        else { $failure += ' SSH stdout incomplete.' }
        if ($null -ne $err -and $err.Wait(5000)) { Write-Utf8 ($Prefix + '.stderr.txt') $err.Result }
        else { $failure += ' SSH stderr incomplete.' }
        $p.Dispose()
        Write-Utf8 ($Prefix + '.status.json') ([pscustomobject]@{exit_code=$code; failure=$failure; elapsed_seconds=$watch.Elapsed.TotalSeconds} | ConvertTo-Json)
    }
    if ($failure -or $null -eq $code -or $code -ne 0) { throw "Guarded card run failed: exit=$code; $failure. Inspect $Prefix.status.json" }
}
# A diagnostic may reuse only an explicitly identified, pinned build workspace.
# It never creates last-build.json or bypasses Build's acceptance checks.
function Get-DiagnosticBase([string]$PreviousRun, [string]$Commit) {
    if (!$PreviousRun) { throw 'Diagnose requires -PreviousRun pointing to the failed Windows artifact directory.' }
    $path = (Resolve-Path -LiteralPath $PreviousRun -ErrorAction Stop).Path
    $name = Split-Path $path -Leaf
    if ($name -notmatch '^run-[A-Za-z0-9-]+$') { throw 'Invalid previous run directory name.' }
    if ($Commit -notmatch '^[a-f0-9]{40}$' -or
        (Get-Content -LiteralPath (Join-Path $path 'source-commit.txt') -Raw -ErrorAction Stop).Trim() -cne $Commit) {
        throw 'Previous source commit differs from this pinned kit.'
    }
    foreach ($file in @('report\build.txt','report\bench-historical.txt','report\bench-patched.txt','report\exit-code.txt')) {
        if (!(Test-Path -LiteralPath (Join-Path $path $file) -PathType Leaf)) { throw "Previous build evidence missing: $file" }
    }
    return '/root/knc-phase3-' + $name
}
function Get-CheckBuildBase([string]$PreviousRun, [string]$Commit) {
    $base = Get-DiagnosticBase -PreviousRun $PreviousRun -Commit $Commit
    $version = (Get-Content -LiteralPath (Join-Path $PreviousRun 'VERSION') -Raw).Trim()
    if ($version -notin @('1.5','1.6','1.7','1.8','1.9')) { throw 'CheckBuild requires a full Build from kit 1.5 or newer supported by this kit.' }
    foreach ($name in @('numerics.txt','quantize.txt','elf.txt','symbols.txt')) {
        if (!(Test-Path -LiteralPath (Join-Path $PreviousRun ('report\' + $name)) -PathType Leaf)) {
            throw "CheckBuild evidence missing: $name"
        }
    }
    $numerics = @(Get-Content -LiteralPath (Join-Path $PreviousRun 'report\numerics.txt'))
    if ($numerics -cnotcontains 'PASS: F32 aligned/unaligned/tails and Q4_K/Q5_K/Q6_K dot products; failures=0') {
        throw 'Prior full Build did not record a numerical PASS; use Diagnose first.'
    }
    return $base
}

# Stage only the Q5 candidate source; never edit the prior source checkout.
function Stage-Q5Candidate([string]$PreviousRun, [string]$Commit, [string]$Destination, [string]$PatchPath) {
    $null = Get-DiagnosticBase -PreviousRun $PreviousRun -Commit $Commit
    $null = Get-Command git.exe -ErrorAction Stop
    $source = Join-Path $PreviousRun 'source'
    $name = 'ggml-phi-knc-dot_q5_K_q8_K.c'
    $lines = & git.exe -C $source show ($Commit + ':' + $name)
    Assert-NativeExit 'Reading original Q5 source from the pinned local Git object'
    if (!$lines) { throw 'Pinned Q5 source is empty.' }
    $null = New-Item -ItemType Directory -Path $Destination -ErrorAction Stop
    $path = Join-Path $Destination $name
    Write-Utf8 $path (($lines -join [char]10) + [char]10)
    & git.exe init --quiet $Destination
    Assert-NativeExit 'Creating isolated candidate patch workspace'
    & git.exe -C $Destination apply --check $PatchPath
    Assert-NativeExit 'Checking Q5 alignment patch'
    & git.exe -C $Destination apply $PatchPath
    Assert-NativeExit 'Applying Q5 alignment patch to the isolated candidate'
    return $path
}

# Logging-only test candidate from the immutable local Git object. No fetch,
# no edits to the prior checkout, no changes to kernels or test assertions.
function Stage-QuantizeTrace([string]$PreviousRun, [string]$Commit, [string]$Destination, [string]$PatchPath) {
    $null = Get-CheckBuildBase -PreviousRun $PreviousRun -Commit $Commit
    $null = Get-Command git.exe -ErrorAction Stop
    $source = Join-Path $PreviousRun 'source'
    $lines = & git.exe -C $source show ($Commit + ':tests/test-quantize-fns.cpp')
    Assert-NativeExit 'Reading upstream quantization test from the pinned local Git object'
    if (!$lines) { throw 'Pinned quantization test is empty.' }
    $null = New-Item -ItemType Directory -Path (Join-Path $Destination 'tests') -ErrorAction Stop
    $path = Join-Path $Destination 'tests\test-quantize-fns.cpp'
    Write-Utf8 $path (($lines -join [char]10) + [char]10)
    & git.exe init --quiet $Destination
    Assert-NativeExit 'Creating isolated test patch workspace'
    & git.exe -C $Destination apply --check $PatchPath
    Assert-NativeExit 'Checking quantization progress patch'
    & git.exe -C $Destination apply $PatchPath
    Assert-NativeExit 'Applying logging-only quantization progress patch'
    return $path
}
