. (Join-Path $PSScriptRoot 'Preparation.ps1')
. (Join-Path $PSScriptRoot 'ModelCache.ps1')
function Write-LiveProgress($Capture,$Diagnostic,[double]$Seconds,[bool]$Complete) {
    $sample=if ($null -ne $Diagnostic) { $Diagnostic.Snapshot } else { $null }
    $bytes=if ($null -ne $Capture) { $Capture.BytesWritten } else { 0L }
    $first=if ($null -ne $Capture -and $Capture.FirstByteMilliseconds -ge 0) { $Capture.FirstByteMilliseconds/1000.0 } else { $null }
    $stage=if ($bytes -gt 0) { 'generating' } elseif ($null -ne $sample) { $sample.Stage } else { 'starting' }
    Write-JsonFile (Join-Path $script:job 'live-progress.json') ([pscustomobject]@{
        stage=$stage;elapsed_seconds=$Seconds;first_byte_seconds=$first;output_bytes=$bytes
        native=$sample;complete=$Complete;updated_utc=[DateTime]::UtcNow.ToString('o')
    })
}
# Background worker only. The UI never waits on these operations.
if (!('PhiChat.DownloadProgressCounter' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'DownloadProgress.cs') }
function Write-JobFailure($Failure) {
    # Preserve the original error before attempting another status-file update.
    # Paths and source locations only; no request object, prompt or model weights.
    $details=[pscustomobject]@{
        state='failed';message=$Failure.Exception.Message;progress=$null
        preserve_ready=($Failure.Exception.Data['PhiChatInput'] -eq $true)
        error_id=$Failure.FullyQualifiedErrorId
        script_name=$Failure.InvocationInfo.ScriptName
        script_line=$Failure.InvocationInfo.ScriptLineNumber
        stack=$Failure.ScriptStackTrace
    }
    Write-Utf8 (Join-Path $script:job 'failure.txt') ($Failure.Exception.ToString()+"`n"+$Failure.ScriptStackTrace)
    Write-JsonFile (Join-Path $script:job 'failure.json') $details
}
function Set-JobStatus([string]$Message,[string]$State='running',$Extra=$null,$Progress=$null) {
    $value=[ordered]@{state=$State;message=$Message;progress=$Progress;updated_utc=(Get-Date).ToUniversalTime().ToString('o')}
    if ($null -ne $script:health) {
        $value.profile=$script:health.profile.profile_id; $value.temperature_c=$script:health.temperature_c
        $value.thermal_warn_c=$script:health.profile.thermal_warn_c; $value.thermal_stop_c=$script:health.profile.thermal_stop_c
        if ($script:health.PSObject.Properties['sampled_utc']) { $value.temperature_sampled_utc=$script:health.sampled_utc }
    }
    if (Get-Variable memoryCheck -Scope Script -ErrorAction SilentlyContinue) { $value.memory=$script:memoryCheck }
    if ($null -ne $Extra) { $value.result=$Extra }
    Write-JsonFile (Join-Path $script:job 'status.json') $value
}
function Set-LoadProgress([string]$Stage,[long]$Bytes,[long]$Total,[double]$ElapsedSeconds,[switch]$Complete) {
    $progress=New-TransferProgress $Stage $Bytes $Total $ElapsedSeconds -Complete:$Complete
    $message='{0}: {1}% - {2:N1} / {3:N1} MiB ({4:N1} MiB/s)' -f $Stage,$progress.percent,($progress.bytes/1MB),($Total/1MB),($progress.bytes_per_second/1MB)
    Set-JobStatus $message -Progress $progress
    # Keep transfer evidence only; no prompt or download credentials.
    [IO.File]::AppendAllText((Join-Path $script:job 'load-progress.jsonl'),($progress | ConvertTo-Json -Compress)+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
}
function Assert-JobActive {
    if ($script:cleanupMode) { return }
    if (Test-Path -LiteralPath (Join-Path $script:job 'cancel')) {
        $script:operatorCancelled=$true
        throw 'Stopped by operator.'
    }
    if ($script:request.owner_pid -gt 0 -and !(Get-Process -Id $script:request.owner_pid -ErrorAction SilentlyContinue)) { throw 'Chat window closed; stopping the card workload.' }
}
function Get-ChatCancellationStatus {
    if ($script:request -and $script:request.PSObject.Properties['action'] -and $script:request.action -ceq 'Chat' -and $script:operatorCancelled -and
        !$script:cardLockOwned -and $script:cleanupConfirmed) {
        return [pscustomobject]@{state='cancelled';message='Response stopped';preserve_ready=$true;progress=$null}
    }
    return $null
}
function Read-CardHealth([switch]$DuringRun) {
    Assert-JobActive
    $script:healthIndex++
    $prefix=Join-Path $script:job ('micinfo-'+$script:healthIndex.ToString('D5'))
    $null=Invoke-CheckedCapture -FilePath $script:connection.micinfo -ReportPrefix $prefix -Quiet -TimeoutMilliseconds 15000
    $text=Get-Content -LiteralPath ($prefix+'.stdout.txt') -Raw
    $h=Read-MicHardware -Text $text -Profiles $script:profiles -AllowWarm:$DuringRun
    $h | Add-Member -NotePropertyName serial -NotePropertyValue (Get-CardSerial $text)
    $h | Add-Member -NotePropertyName sampled_utc -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o'))
    if ($script:health -and $h.serial -cne $script:health.serial) { throw 'Card identity changed during operation.' }
    $script:health=$h
    [pscustomobject]@{time_utc=(Get-Date).ToUniversalTime().ToString('o');profile=$h.profile.profile_id;serial=$h.serial;temperature_c=$h.temperature_c;frequency_khz=$h.frequency_khz;ecc=$h.ecc} |
        Export-Csv -LiteralPath (Join-Path $script:job 'telemetry.csv') -Append -NoTypeInformation
    if ($h.temperature_c -ge $h.profile.thermal_warn_c) { Set-JobStatus 'Temperature warning; stop threshold remains active.' }
    return $h
}
function Update-LoadTemperature {
    if ($script:health -and $script:health.PSObject.Properties['sampled_utc'] -and
        ((Get-Date).ToUniversalTime()-[DateTimeOffset]::Parse([string]$script:health.sampled_utc).UtcDateTime).TotalSeconds -lt [int]$script:cfg.poll_seconds) { return }
    $null=Read-CardHealth -DuringRun
}
function Invoke-JobProcess([string]$Exe,[string[]]$Arguments,[int]$Seconds=120,[string]$OutputPath='', [switch]$Guarded,[scriptblock]$OnTick=$null) {
    Assert-JobActive
    $script:processIndex++
    $prefix=Join-Path $script:job ('process-'+$script:processIndex.ToString('D4'))
    $operation=if (Get-Variable activity -Scope Script -ErrorAction SilentlyContinue) { $script:activity } else { 'card operation' }
    $p=New-Object Diagnostics.Process
    $p.StartInfo.FileName=$Exe
    $p.StartInfo.Arguments=Join-NativeArguments $Arguments
    $p.StartInfo.UseShellExecute=$false; $p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardInput=$true; $p.StartInfo.RedirectStandardOutput=$true; $p.StartInfo.RedirectStandardError=$true
    $p.StartInfo.StandardOutputEncoding=New-Object Text.UTF8Encoding($false)
    $p.StartInfo.StandardErrorEncoding=New-Object Text.UTF8Encoding($false)
    $out=$null; $err=$null; $stream=$null; $capture=$null; $diagnostic=$null; $nextLive=0.0; $code=$null; $started=$false; $failure=''; $answer=''
    $watch=[Diagnostics.Stopwatch]::StartNew(); $nextHealth=0.0; $nextTick=0.0
    try {
        $started=$p.Start(); if (!$started) { throw 'Process did not start.' }
        if ($OutputPath) {
            $stream=New-Object IO.FileStream($OutputPath,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite,4096,[IO.FileOptions]::WriteThrough)
            $capture=New-Object PhiChat.LiveCapture
            $out=$capture.CopyAsync($p.StandardOutput.BaseStream,$stream)
        } else { $out=$p.StandardOutput.ReadToEndAsync() }
        if ($Guarded) {
            $diagnostic=New-Object PhiChat.DiagnosticCapture
            $err=$diagnostic.ReadAsync($p.StandardError)
        } else { $err=$p.StandardError.ReadToEndAsync() }
        if ($Guarded) { $p.StandardInput.WriteLine('health-ok'); $p.StandardInput.Flush() }
        else { $p.StandardInput.Close() }
        while (!$p.WaitForExit(200)) {
            Assert-JobActive
            if ($Guarded -and $watch.Elapsed.TotalSeconds -ge $nextLive) {
                Write-LiveProgress $capture $diagnostic $watch.Elapsed.TotalSeconds $false
                $nextLive=$watch.Elapsed.TotalSeconds+1
            }
            if ($watch.Elapsed.TotalSeconds -gt $Seconds) { throw 'Operation wall-clock timeout reached.' }
            if ($null -ne $OnTick -and $watch.Elapsed.TotalSeconds -ge $nextTick) {
                $null=& $OnTick $watch.Elapsed.TotalSeconds
                $nextTick=$watch.Elapsed.TotalSeconds+1.0
            }
            if ($Guarded -and $watch.Elapsed.TotalSeconds -ge $nextHealth) {
                $null=Read-CardHealth -DuringRun
                $nextHealth=$watch.Elapsed.TotalSeconds+[int]$script:cfg.poll_seconds
                Set-JobStatus $script:activity
                if (!$p.HasExited) { $p.StandardInput.WriteLine('health-ok'); $p.StandardInput.Flush() }
            }
        }
        $code=$p.ExitCode
    } catch { $failure=$_.Exception.Message }
    finally {
        if ($started) {
            try { $p.StandardInput.Close() } catch {}
            try {
                # EOF asks the native guard to stop and collect evidence. SCP has
                # no guard: interrupt a failed/cancelled transfer immediately.
                if ($failure -and !$Guarded -and !$p.HasExited) { $p.Kill() }
                if (!$p.HasExited -and !$p.WaitForExit(5000)) { $p.Kill(); $null=$p.WaitForExit(3000) }
                if ($p.HasExited) { $code=$p.ExitCode }
            } catch { $failure+=' Could not stop local SSH cleanly; card lease will expire.' }
        }
        try {
            if ($null -eq $out -or !$out.Wait(5000)) { throw 'stdout incomplete' }
            if (!$OutputPath) { $answer=$out.Result; Write-Utf8 ($prefix+'.stdout.txt') $answer }
        } catch { $failure+=' Output capture failed.' }
        if ($null -ne $stream) { $stream.Dispose() }
        if ($null -ne $capture) {
            $first=if ($capture.FirstByteMilliseconds -ge 0) { $capture.FirstByteMilliseconds/1000.0 } else { $null }
            Write-JsonFile (Join-Path $script:job 'response-stream.json') ([pscustomobject]@{first_byte_seconds=$first;elapsed_seconds=$watch.Elapsed.TotalSeconds;bytes=$capture.BytesWritten})
        }
        try {
            if ($null -ne $err -and $err.Wait(5000)) { Write-Utf8 ($prefix+'.stderr.txt') $err.Result }
            else { $failure+=' stderr incomplete.' }
        } catch { $failure+=' Error capture failed.' }
        if ($Guarded) { Write-LiveProgress $capture $diagnostic $watch.Elapsed.TotalSeconds $true }
        $p.Dispose()
        Write-JsonFile ($prefix+'.exit.json') ([pscustomobject]@{exit_code=$code;elapsed_seconds=$watch.Elapsed.TotalSeconds;failure=$failure;guarded=[bool]$Guarded;executable=[IO.Path]::GetFileName($Exe);operation=$operation;stdout=$(if ($OutputPath) {$OutputPath} else {$prefix+'.stdout.txt'});stderr=($prefix+'.stderr.txt')})
    }
    if ($failure -or $null -eq $code -or $code -ne 0) {
        $detail=''
        if (Test-Path -LiteralPath ($prefix+'.stderr.txt')) { $detail=(@(Get-Content -LiteralPath ($prefix+'.stderr.txt') | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' ') }
        throw "Process failed (exit=$code): $failure $detail. Evidence: $prefix"
     }
    return $answer
}
function Invoke-Card([string]$Command) {
    # PowerShell here-strings inherit CRLF from Windows source checkouts.
    # The card's Linux shell requires LF, including for `set -eu` and heredocs.
    $Command=$Command.Replace("`r`n","`n")
    return Invoke-JobProcess $script:ssh ($script:sshOptions+@('-T',$script:target,$Command))
}
function Send-CardFiles([string[]]$Local,[string]$Remote) {
    $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+$Local+@($script:target+':'+$Remote)) 900
}
function Receive-CardReport([string]$Remote,[string]$Local) {
    $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+@('-r',($script:target+':'+$Remote),$Local)) 120
}
function Require-CardMemory($Model,[switch]$IncludeModelFile,[string]$Snapshot='') {
    $need=Get-MemoryRequirement $Model $script:health.profile -IncludeModelFile:$IncludeModelFile
    $raw=if ($Snapshot) { $Snapshot } else { Invoke-Card 'cat /proc/meminfo' }
    $memory=Read-MemorySnapshot $raw
    $stage=if ($IncludeModelFile) { 'Before model copy' } else { 'Before inference' }
    $script:memoryCheck=[pscustomobject]@{stage=$stage;snapshot=$memory;requirement=$need}
    Write-Utf8 (Join-Path $script:job ('memory-'+$(if ($IncludeModelFile) { 'before-copy' } else { 'before-inference' })+'.txt')) $raw
    [IO.File]::AppendAllText((Join-Path $script:job 'memory-admission.jsonl'),($script:memoryCheck | ConvertTo-Json -Depth 5 -Compress)+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
    $forecastPath=Join-Path $script:job 'forecast.json'
    if (Test-Path -LiteralPath $forecastPath -PathType Leaf) {
        $forecast=Read-JsonFile $forecastPath
        $forecast.last_available_mib=[math]::Floor($memory.available_kib/1024)
        $forecast.estimated_headroom_mib=$forecast.last_available_mib-$need.required_mib
        $forecast.memory_risk=($forecast.memory_risk -or $forecast.estimated_headroom_mib -lt 0)
        Write-JsonFile $forecastPath $forecast
    }
    $availableMiB=[math]::Round($memory.available_kib/1024,1)
    $detail="$stage requires $($need.required_mib) MiB (model copy $($need.model_file_mib), additional runtime $($need.runtime_mib), reserve $($need.reserve_mib)); allocatable GDDR $availableMiB MiB; raw free $([math]::Round($memory.free_kib/1024,1)) MiB."
    if ($memory.available_kib -lt $need.required_mib*1024) {
        $shortfall=[math]::Ceiling($need.required_mib-$memory.available_kib/1024)
        throw "Insufficient allocatable GDDR: $detail Short by $shortfall MiB. RAM-backed files still use GDDR; unrelated card files were left in place."
    }
    Set-JobStatus $detail
}
function Find-LocalModel($Model) {
    if ($Model.PSObject.Properties['local_only'] -and $Model.local_only) {
        if ($Model.model_path -notmatch '^models/uniform-q5-k/[A-Za-z0-9_.-]+\.gguf$') { throw 'Invalid local quantization path.' }
        $local=Join-Path $script:connection.project_dir $Model.model_path
        if (Test-Path -LiteralPath $local -PathType Leaf) { return $local }
        return ''
    }
    $cache=Join-Path $script:connection.project_dir 'models'
    $path=Join-Path $cache $Model.filename
    if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    $found=Get-ChildItem -LiteralPath $script:connection.project_dir -Filter $Model.filename -File -Recurse | Select-Object -First 1
    if ($found) { return $found.FullName }
    return ''
}
function Receive-ModelDownload([uri]$Uri,[string]$Path,[long]$TotalBytes,[int]$Seconds=3600) {
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $client=New-Object Net.WebClient
    $counter=New-Object PhiChat.DownloadProgressCounter
    $progressHandler=$counter.Handler
    $watch=[Diagnostics.Stopwatch]::StartNew(); $received=0L; $complete=$false; $task=$null
    $client.add_DownloadProgressChanged($progressHandler)
    try {
        Set-LoadProgress 'Downloading to Windows' 0 $TotalBytes 0
        $task=$client.DownloadFileTaskAsync($Uri,$Path)
        while (!$task.IsCompleted) {
            Assert-JobActive
            Update-LoadTemperature
            if ($watch.Elapsed.TotalSeconds -gt $Seconds) { throw 'Model download timed out. Click Load model to retry.' }
            # The C# callback keeps one atomic counter; there are no PowerShell
            # event IDs to expire or remove and no progress-event backlog.
            $latest=$counter.ReceivedBytes
            if ($latest -ne $received) {
                $received=$latest
                Set-LoadProgress 'Downloading to Windows' $received $TotalBytes $watch.Elapsed.TotalSeconds
            }
            Start-Sleep -Milliseconds 200
        }
        Assert-JobActive
        $null=$task.GetAwaiter().GetResult()
        $actual=(Get-Item -LiteralPath $Path).Length
        if ($actual -ne $TotalBytes) { throw "Incomplete model download: $actual of $TotalBytes bytes." }
        Set-LoadProgress 'Downloading to Windows' $actual $TotalBytes $watch.Elapsed.TotalSeconds -Complete
        $complete=$true
    } finally {
        $client.CancelAsync()
        if ($null -ne $task -and !$task.IsCompleted) { try { $null=$task.Wait(3000) } catch {} }
        $client.remove_DownloadProgressChanged($progressHandler)
        $client.Dispose()
        if (!$complete) { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue }
    }
}
function Get-LocalModel($Model) {
    Set-JobStatus 'Locating the selected model on Windows.'
    $cache=Join-Path $script:connection.project_dir 'models'
    if (Test-Path -LiteralPath $cache -PathType Leaf) { throw "The model-cache path is a file, not a directory: $cache. Existing data was preserved." }
    $null=New-Item -ItemType Directory -Path $cache -Force
    $path=Join-Path $cache $Model.filename
    $found=Find-LocalModel $Model
    if ($found) { $path=$found }
    else {
        if ($Model.PSObject.Properties['local_only'] -and $Model.local_only) {
            if ($Model.id.EndsWith('-projector')) { throw 'Import the Step3-Vision pack with Add-Models.cmd, then Load model again.' }
            throw ('Local Q5_K file is missing: '+$Model.model_path+'. Install the optimized models pack with Setup.cmd -Mode AddModels; this generated model is not available from the upstream download.')
        }
        # Separate temporary paths prevent two app instances sharing a download.
        $part=$path+'.'+[Guid]::NewGuid().ToString('N')+'.part'
        try {
            $url='https://huggingface.co/'+$Model.repository+'/resolve/'+$Model.revision+'/'+$Model.filename
            Receive-ModelDownload ([uri]$url) $part ([long]$Model.file_size_bytes)
            try { [IO.File]::Move($part,$path) }
            catch [IO.IOException] {
                # Another app may have completed the same download. Keep its file
                # and validate it below. Never overwrite/delete an existing GGUF.
                if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Cannot save downloaded model to '$path': $($_.Exception.Message)" }
            }
        } finally { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
    }
    Set-JobStatus 'Checking the Windows model file.'
    Assert-ModelFile $path $Model (Join-Path $script:data ('model-'+$Model.id+'.json'))
    Assert-JobActive
    return $path
}
function Send-ModelFile([string]$LocalPath,[string]$RemotePath,[long]$TotalBytes) {
    $watch=[Diagnostics.Stopwatch]::StartNew()
    Set-LoadProgress 'Copying to Xeon Phi' 0 $TotalBytes 0
    $tick={
        param([double]$ElapsedSeconds)
        Update-LoadTemperature
        # ls reads file metadata; it does not scan a growing multi-GB file.
        $command="if test -f '$RemotePath'; then ls -ln '$RemotePath' | awk '{print `$5}'; else echo 0; fi"
        # Bound progress polling too, so a stalled SSH query cannot hide the
        # temperature check for the normal two-minute command timeout.
        $bytes=(Invoke-JobProcess $script:ssh ($script:sshOptions+@('-T',$script:target,$command)) 10).Trim()
        if ($bytes -notmatch '^\d+$') { throw 'Cannot read model transfer progress from the Phi.' }
        Set-LoadProgress 'Copying to Xeon Phi' ([long]$bytes) $TotalBytes $ElapsedSeconds
    }
    $null=Read-CardHealth
    $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+@($LocalPath,($script:target+':'+$RemotePath))) 900 -OnTick $tick
    $actual=(Invoke-Card "LC_ALL=C ls -ln '$RemotePath' | awk '{print `$5}'").Trim()
    if ($actual -cne [string]$TotalBytes) { throw 'Model transfer did not complete; click Load model to retry.' }
    Set-LoadProgress 'Copying to Xeon Phi' $TotalBytes $TotalBytes $watch.Elapsed.TotalSeconds -Complete
}
function Acquire-CardWorkloadLock {
    $script:cardLockToken=[Guid]::NewGuid().ToString('N')
    # The same atomic directory lock is used by Phase 3 and the inference worker.
    $command="if mkdir /tmp/knc-phase3-workload.lock 2>/dev/null; then printf '%s\n' '$($script:cardLockToken)' > /tmp/knc-phase3-workload.lock/phi-chat-owner; else echo 'Another workload or retained lock exists; stop that workload before switching models.' >&2; exit 1; fi"
    # Even a lost SSH response may have created our lock; attempt token-scoped cleanup.
    $script:cardLockOwned=$true; $script:cleanupConfirmed=$false
    try { $null=Invoke-Card $command }
    catch { Release-CardWorkloadLock; throw }
}
function Release-CardWorkloadLock {
    if (!$script:cardLockOwned) { return }
    $priorCleanup=$script:cleanupMode; $script:cleanupMode=$true
    try {
        $null=Invoke-Card "if test -f /tmp/knc-phase3-workload.lock/phi-chat-owner && test `"`$(cat /tmp/knc-phase3-workload.lock/phi-chat-owner)`" = '$($script:cardLockToken)'; then if test -f /tmp/knc-phase3-workload.lock/worker-pid && kill -0 `"`$(cat /tmp/knc-phase3-workload.lock/worker-pid)`" 2>/dev/null; then :; else rm -f /tmp/knc-phase3-workload.lock/phi-chat-owner /tmp/knc-phase3-workload.lock/worker-pid && rmdir /tmp/knc-phase3-workload.lock; fi; fi"
        $confirmed=(Invoke-Card "if test ! -d /tmp/knc-phase3-workload.lock; then printf clean; fi").Trim()
        if ($confirmed -cne 'clean') { throw 'Card workload cleanup is not confirmed; reconnect before sending.' }
        $script:cardLockOwned=$false
        $script:cleanupConfirmed=$true
    } finally { $script:cleanupMode=$priorCleanup }
}
function Get-RemoteModelIdentity([string]$Remote) {
    return (Invoke-Card "if test -f '$Remote' && test -f '$Remote.identity'; then cat '$Remote.identity'; LC_ALL=C ls -ln '$Remote' | awk '{print `$5}'; fi").Trim()
}
function Get-CardModel($Model,$State,[string]$LocalPath) {
    Assert-ModelBudget $Model $script:health.profile
    if (!$script:cardLockOwned) { throw 'Card staging requires the workload lock.' }
    $base=$State.remote_base
    Remove-OtherCardModels $Model $State
    if ($State.PSObject.Properties['model_sha256'] -and $State.model_sha256 -ceq $Model.sha256) {
        $size=(Invoke-Card "if test -f '$base/model.gguf'; then LC_ALL=C ls -ln '$base/model.gguf' | awk '{print `$5}'; else echo 0; fi").Trim()
        if ($size -ceq [string]$Model.file_size_bytes) { return "$base/model.gguf" }
    }
    $remote="$base/models/$($Model.id).gguf"
    $present=Get-RemoteModelIdentity $remote
    if (($present -split '\s+') -join ' ' -ceq "$($Model.sha256) $($Model.file_size_bytes)") { return $remote }
    # A .part is a disposable, interrupted transfer of this exact cached model.
    $null=Invoke-Card "mkdir -p '$base/models' && rm -f '$remote.part'"
    # The declared minimum is a card-eligibility class, not an allocation request.
    # Reserve the actual new file plus estimated runtime and headroom, once each.
    Require-CardMemory $Model -IncludeModelFile
    Set-JobStatus 'Copying the selected model to card RAM. The Windows copy is persistent.'
    try {
        Send-ModelFile $LocalPath ($remote+'.part') ([long]$Model.file_size_bytes)
        $null=Invoke-Card "test `"`$(LC_ALL=C ls -ln '$remote.part' | awk '{print `$5}')`" = '$($Model.file_size_bytes)' && mv '$remote.part' '$remote' && printf '%s\n' '$($Model.sha256)' > '$remote.identity'"
    } catch {
        $priorCleanup=$script:cleanupMode; $script:cleanupMode=$true
        try { $null=Invoke-Card "rm -f '$remote.part'" } finally { $script:cleanupMode=$priorCleanup }
        throw
    }
    return $remote
}
function Get-PreparedCardModel($Ready,$Model,$State) {
    Assert-ModelReady $Ready $Model $State $script:health
    $remote=$Ready.remote_model
    if ($remote -ceq "$($State.remote_base)/model.gguf") {
        $size=(Invoke-Card "if test -f '$remote'; then LC_ALL=C ls -ln '$remote' | awk '{print `$5}'; else echo 0; fi").Trim()
        if ($size -ceq [string]$Model.file_size_bytes) { return $remote }
    } else {
        $present=Get-RemoteModelIdentity $remote
        if (($present -split '\s+') -join ' ' -ceq "$($Model.sha256) $($Model.file_size_bytes)") { return $remote }
    }
    throw 'The selected model is no longer ready on the Phi. Click Load model again.'
}
function Get-CheckedChatPrompt($Model,$State,[string]$RemoteModel,$Threads,[object[]]$Messages,[string]$System,[int]$Tokens) {
    $budget=Get-PromptBudget ([int]$Model.context_tokens) $Tokens
    $prompt=New-ChatPrompt $Model $Messages $System $Tokens
    $baseModel=Get-ModelProfile $script:root $script:request.model
    $automatic=($Tokens -eq 0)
    $allocationKey=Get-AllocationKey $Model $State $Threads
    $allocated=($Model.context_tokens -ne $baseModel.context_tokens -and (Test-AllocationReceipt $allocationKey))
    $script:allocationReused=$allocated
    for ($attempt=1; $attempt -le 2; $attempt++) {
        $script:promptImages=@($prompt.images)
        $count=$null
        $fits=($prompt.utf8_upper_bound -le $budget)
        # Reuse measured 4K allocation only for the same boot/model/settings.
        # Prompt counts are never reused; inconclusive bounds still tokenize.
        if ($automatic -or $script:promptImages.Count -or !$fits -or ($Model.context_tokens -ne $baseModel.context_tokens -and !$allocated)) {
            $check=Invoke-Generation $Model $State $RemoteModel $prompt.text $Threads $Tokens (Join-Path $script:job ('prompt-check-'+$attempt)) -CheckOnly
            $count=$check.prompt_tokens
            $fits=($count -le $budget -and !$check.prompt_rejected)
        }
        if ($fits) {
            if ($automatic) { $Tokens=[int]$Model.context_tokens-[int]$count-64; $script:request.output_tokens=$Tokens }
            if ($Model.context_tokens -ne $baseModel.context_tokens -and $null -ne $count) { Save-AllocationReceipt $allocationKey $check }
            Write-JsonFile (Join-Path $script:job 'prompt-budget.json') ([pscustomobject]@{context_tokens=$Model.context_tokens;reserved_reply_tokens=$Tokens;margin_tokens=64;prompt_budget=$budget;prompt_tokens=$count;utf8_upper_bound=$prompt.utf8_upper_bound;omitted_pairs=$prompt.omitted_pairs;native_counted=($null -ne $count);image_count=$script:promptImages.Count;prompt_positions=$count;position_contract='Step3 normal positions equal expanded tokens'})
            return $prompt
        }
        if ($prompt.omitted_pairs -eq 0 -and $Messages.Count -gt 1) {
            # One bounded retry with the newest turn, never one model reload per
            # historical message. The visible transcript remains intact.
            Set-JobStatus 'Conversation exceeds context; keeping the system message and your newest question.'
            $prompt=New-ChatPrompt $Model $Messages $System $Tokens -LatestOnly
            continue
        }
        Stop-ChatInput ("Your newest message plus the system/template uses {0} tokens; {1} fit with a {2}-token reply in {3} context. Split the message or select a model with more available context. Your draft and loaded model are kept." -f $count,$budget,$Tokens,$Model.context_tokens)
    }
    throw 'Prompt selection did not complete.'
}
function Invoke-Generation($Model,$State,[string]$RemoteModel,[string]$Prompt,$Threads,[int]$Tokens,[string]$Directory,[switch]$CheckOnly) {
    Update-PreparationHealth
    Require-CardMemory $Model -Snapshot $script:preparedMemory
    $script:preparedMemory=''
    Assert-JobActive
    $remote='/root/knc-chat-'+[Guid]::NewGuid().ToString('N')
    $alreadyPrepared=[bool]$script:preparedRemote
    if ($alreadyPrepared) { $remote=$script:preparedRemote; $script:preparedRemote='' }
    $null=New-Item -ItemType Directory -Path $Directory
    $inputPath=Join-Path $Directory 'prompt.txt'
    $settings=Join-Path $Directory 'settings.sh'
    $streamPath=Join-Path $script:job 'response.txt'
    if ($CheckOnly) { $streamPath=Join-Path $Directory 'check-output.txt' }
    $telemetryStart=$script:healthIndex
    $inputImages=@(); $imageFiles=@()
    if (Get-Variable -Name promptImages -Scope Script -ErrorAction SilentlyContinue) { $inputImages=@($script:promptImages) }
    if ($inputImages.Count) {
        if (!(Test-ImageModel $Model) -or 'knc-text-image-r1' -cnotin @($State.modern_features)) { Stop-ChatInput 'Image input requires the matching multimodal runtime.' }
    }
    $values=[ordered]@{
        IMAGE_COUNT=$inputImages.Count
        PROJECTOR_PATH=$(if ($inputImages.Count) {$script:remoteProjector} else {'none'})
        PROJECTOR_BYTES=$(if ($inputImages.Count) {$Model.projector.file_size_bytes} else {0})
        PROJECTOR_SHA256=$(if ($inputImages.Count) {$Model.projector.sha256} else {'none'})
        RUNTIME_FAMILY=$(if (Test-ModernTextModel $Model) { 'modern-knc' } else { 'historical-knc' }); MODERN_RUNTIME_ID=$(if ($State.PSObject.Properties['modern_runtime_id']) { $State.modern_runtime_id } else { 'none' })
        MODERN_SOURCE_COMMIT=$(if ($State.PSObject.Properties['modern_source_commit']) { $State.modern_source_commit } else { 'none' })
        MODERN_TEST_MODE=$(if (!$CheckOnly -and (Test-ModernTextModel $Model) -and $script:request.PSObject.Properties['modern_test_mode']) { $script:request.modern_test_mode } else { 'none' })
        MODERN_ENGINE_VARIANT=(Get-ModelEngineVariant $Model)
        MQ_ROWS=$(if ($Threads.PSObject.Properties['mq_rows']) { [int]$Threads.mq_rows } else { 4 })
        STOP_TOKEN_IDS=$(if ($Model.PSObject.Properties['stop_token_ids']) { $Model.stop_token_ids -join ',' } else { '' })
        LOCK_TOKEN=$script:cardLockToken; SOURCE_COMMIT=$script:cfg.source_commit; MODEL_PATH=$RemoteModel; MODEL_BYTES=[long]$Model.file_size_bytes
        THREADS=[int]$Threads.generation; PROMPT_THREADS=[int]$Threads.prompt; CORES=[int]$script:health.cores
        PREDICT=$Tokens; BATCH=[int]$script:request.batch; SEED=[int]$script:cfg.seed
        CONTEXT=[int]$Model.context_tokens; RUN_MODE=$(if ($CheckOnly) { 'check' } else { 'generate' })
        RUNTIME_ADMIT_MIB=[int]$Model.estimated_peak_runtime_mib
        # Allow growth to the hardware budget, not just the initial estimate.
        RUNTIME_LIMIT_MIB=([int]$script:health.profile.safe_memory_budget_mib-[int][math]::Ceiling($Model.file_size_bytes/1MB)-$(if ($Model.PSObject.Properties['extra_resident_mib']) {$Model.extra_resident_mib} else {0}))
        MEMORY_STOP_MIB=[int]$script:health.profile.available_reserve_mib
    }
    $lines=foreach ($entry in $values.GetEnumerator()) {
        if ($entry.Key -ceq 'STOP_TOKEN_IDS') {
            if ([string]$entry.Value -notmatch '^([0-9]{1,6}(,[0-9]{1,6}){0,15})?$') { throw 'Unsafe stop-token setting.' }
        } elseif ([string]$entry.Value -notmatch '^[A-Za-z0-9_./-]+$') { throw 'Unsafe native setting.' }
        "$($entry.Key)='$($entry.Value)'"
    }
    Write-Utf8 $inputPath $Prompt
    Write-Utf8 $settings (($lines -join [char]10)+[char]10)
    $failure=''
    try {
        foreach ($im in $inputImages) {
            $file=Assert-StoredImage $script:data $im
            $copy=Join-Path $Directory ('image-'+$imageFiles.Count+'.png')
            $imageFiles+=@($copy)
            Copy-Item -LiteralPath $file -Destination $copy
        }
        if (!$alreadyPrepared) { $null=Invoke-Card "mkdir '$remote'" }
        Send-CardFiles @($inputPath,$settings,(Join-Path $script:root 'scripts\chat-worker.sh'),(Join-Path $script:root 'scripts\engine-llama-cli-v1.sh'),(Join-Path $script:root 'scripts\elf-check.sh'),(Join-Path $script:root 'scripts\memory-info.awk'),(Join-Path $script:root 'scripts\model-map.awk'),(Join-Path $script:root 'scripts\prompt-count.awk')) ($remote+'/')
        if ($imageFiles.Count) { Send-CardFiles $imageFiles ($remote+'/') }
        Update-PreparationHealth
        $wall=[int]$script:cfg.generation_timeout_seconds
        $command="exec '$($State.remote_base)/guard' $wall $($script:cfg.heartbeat_timeout_seconds) bash '$remote/chat-worker.sh' '$($State.remote_base)' '$remote'"
        $script:activity="Running on $($script:health.profile.profile_id): $($Threads.generation) generation / $($Threads.prompt) prompt threads; shared model mapping; text streams as generated."
        if ($CheckOnly) { $script:activity="Checking $($Model.context_tokens)-token context allocation and counting prompt tokens on Xeon Phi; no answer generation yet." }
        Set-JobStatus $script:activity
        if (!$CheckOnly) {
            $script:preparationSeconds=$script:preparationWatch.Elapsed.TotalSeconds
            Write-JsonFile (Join-Path $script:job 'preparation-timing.json') ([pscustomobject]@{seconds_to_generation_launch=$script:preparationSeconds;allocation_reused=$script:allocationReused;includes_native_prompt_prechecks=$true;note='Starts in the job process; excludes UI launch overhead. Native initialization/prefill follows this boundary.'})
        }
        $null=Invoke-JobProcess $script:ssh ($script:sshOptions+@('-T',$script:target,$command)) ($wall+30) $streamPath -Guarded
    } catch { $failure=$_.Exception.Message }
    finally {
        Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue
        foreach ($file in $imageFiles) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
        # Bounded cleanup remains possible after cancellation or window closure.
        $script:cleanupMode=$true
        try { Receive-CardReport ($remote+'/report') (Join-Path $Directory 'report') }
        catch { $failure+=' Report collection: '+$_.Exception.Message }
        # Handles a transfer/start failure before the worker installed its trap.
        try { $null=Invoke-Card "rm -f '$remote/prompt.txt' '$remote/image-0.png' '$remote/image-1.png' '$remote/image-2.png' '$remote/image-3.png'" } catch { $failure+=' Remote prompt cleanup unconfirmed; card path: '+$remote+'/prompt.txt' }
        $script:cleanupMode=$false
    }
    if ($failure) {
        Write-JsonFile (Join-Path $Directory 'outcome.json') ([pscustomobject]@{completed=$false;failure=$failure;context=$Model.context_tokens;model_id=$Model.id;mode=$(if ($CheckOnly) {'check'} else {'generate'})})
        $nativeLog=Join-Path $Directory 'report/timing.txt'
        if (Test-Path -LiteralPath $nativeLog) {
            $tail=@(Get-Content -LiteralPath $nativeLog | Where-Object { $_.Trim() } | Select-Object -Last 3) -join ' '
            if ($tail) { $failure+=' Native runtime: '+$tail }
        }
        throw $failure
    }
    $code=(Get-Content -LiteralPath (Join-Path $Directory 'report\exit-code.txt') -Raw).Trim()
    if ($code -cne 'exit_code=0') { throw 'Card worker did not record success.' }
    $mapping=(Get-Content -LiteralPath (Join-Path $Directory 'report\model-mapping.txt') -Raw).Trim()
    if ($mapping -cne 'PASS: read-only shared model mapping observed') { throw 'Shared model mapping was not confirmed on the card; no copy-mode fallback.' }
    if ($CheckOnly) {
        $raw=(Get-Content -LiteralPath (Join-Path $Directory 'report/prompt-count.txt') -Raw).Replace("`r`n","`n")
        $match=[regex]::Match($raw,'\Aprompt_tokens=([0-9]+)\nprompt_rejected=([01])\nnative_exit_code=([01])\n?\z')
        if (!$match.Success) { throw 'Native prompt count evidence is missing or malformed.' }
        $count=[int]$match.Groups[1].Value
        $rejected=($match.Groups[2].Value -ceq '1')
        $exitCode=[int]$match.Groups[3].Value
        if ($count -lt 1 -or $rejected -ne ($exitCode -eq 1) -or $rejected -ne ($count -gt $Model.context_tokens-4)) { throw 'Native prompt count and exit status disagree.' }
        $samples=@(Import-Csv -LiteralPath (Join-Path $Directory 'report/memory.csv'))
        if (!$samples.Count) { throw 'Context allocation has no measured memory samples.' }
        $check=[pscustomobject]@{context_tokens=$Model.context_tokens;prompt_tokens=$count;prompt_rejected=$rejected;native_exit_code=$exitCode;memory_samples=$samples.Count;model_sha256=$Model.sha256;source_commit=$State.source_commit;serial=$script:health.serial;batch=$script:request.batch}
        Write-JsonFile (Join-Path $Directory 'context-check.json') $check
        return $check
    }
    $answer=[IO.File]::ReadAllText($streamPath,[Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($answer)) { throw 'The model returned no answer.' }
    $timing=Read-LlamaTiming (Get-Content -LiteralPath (Join-Path $Directory 'report\timing.txt') -Raw)
    # Timing is informative. A successful short reply is not rejected for missing timing.
    $samples=@(Import-Csv -LiteralPath (Join-Path $Directory 'report\memory.csv'))
    $peak=($samples | ForEach-Object { [long]$_.vmhwm_kib } | Measure-Object -Maximum).Maximum
    $free=($samples | ForEach-Object { [long]$_.memfree_kib } | Measure-Object -Minimum).Minimum
    $additional=($samples | ForEach-Object { [long]$_.additional_rss_kib } | Measure-Object -Maximum).Maximum
    $mapped=($samples | ForEach-Object { [long]$_.model_rss_kib } | Measure-Object -Maximum).Maximum
    $streamTiming=Read-JsonFile (Join-Path $script:job 'response-stream.json')
    $thermal=@(Import-Csv -LiteralPath (Join-Path $script:job 'telemetry.csv') | Select-Object -Skip ([math]::Max(0,$telemetryStart-1)))
    $maxTemp=($thermal | ForEach-Object { [int]$_.temperature_c } | Measure-Object -Maximum).Maximum
    $row=[pscustomobject]@{model_id=$Model.id;model_sha256=$Model.sha256;source_commit=$script:cfg.source_commit;profile=$script:health.profile.profile_id;serial=$script:health.serial;generation_threads=$Threads.generation;prompt_threads=$Threads.prompt;batch=$script:request.batch;context=$Model.context_tokens;load_ms=$timing.load_ms;prompt_tps=$timing.prompt_tps;generation_tps=$timing.generation_tps;generation_tokens=$timing.generation_tokens;peak_rss_mib=([math]::Round($peak/1024,1));min_free_mib=([math]::Round($free/1024,1));peak_temperature_c=$maxTemp}
    $row | Add-Member -NotePropertyName preparation_seconds -NotePropertyValue $script:preparationSeconds
    $row | Add-Member -NotePropertyName allocation_reused -NotePropertyValue $script:allocationReused
    $row | Add-Member -NotePropertyName runtime_source_commit -NotePropertyValue $(if (Test-ModernTextModel $Model) { $State.modern_source_commit } else { $State.source_commit })
    $row | Add-Member -NotePropertyName runtime_family -NotePropertyValue $(if (Test-ModernTextModel $Model) { 'modern-knc' } else { 'historical-knc' })
    $row | Add-Member -NotePropertyName memory_mode -NotePropertyValue 'shared_mmap'
    $row | Add-Member -NotePropertyName peak_additional_rss_mib -NotePropertyValue ([math]::Round($additional/1024,1))
    $row | Add-Member -NotePropertyName peak_model_rss_mib -NotePropertyValue ([math]::Round($mapped/1024,1))
    $row | Add-Member -NotePropertyName first_byte_seconds -NotePropertyValue $streamTiming.first_byte_seconds
    $row | Add-Member -NotePropertyName inference_wall_seconds -NotePropertyValue $streamTiming.elapsed_seconds
    Write-JsonFile (Join-Path $Directory 'metrics.json') $row
    return [pscustomobject]@{answer=$answer;metrics=$row}
}
