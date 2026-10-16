. (Join-Path $PSScriptRoot 'PrimeClient.ps1')
. (Join-Path $PSScriptRoot 'Performance.ps1')
if (!('PhiChat.PrimeFrames' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'PrimeFrames.cs') }

function Get-PrimingPayload($Model,$State) {
    $pin=Read-JsonFile (Join-Path $script:root 'config/priming-runtime.json')
    $found=@($pin.payloads | Where-Object { $_.profile -ceq $script:health.profile.profile_id })
    if (!$found.Count) {return $null}
    if ($found.Count -ne 1 -or $pin.protocol -ne 1 -or $pin.base_source_commit -cne $State.modern_source_commit -or
        $found[0].base_runtime_id -cne $State.modern_runtime_id -or (Get-ModelEngineVariant $Model) -cne 'shared') {throw 'Priming runtime does not match the selected engine.'}
    foreach ($field in @('sha256','runner_sha256','library_sha256')) {
        if ($found[0].$field -cnotmatch '^[a-f0-9]{64}$') {throw 'Invalid pinned priming identity.'}
    }
    $selected=$found[0].PSObject.Copy()
    if ($selected.PSObject.Properties['model_overrides']) {
        $matches=@($selected.model_overrides | Where-Object {$_.model_id -ceq $Model.id})
        if ($matches.Count -gt 1) {throw 'Duplicate model runtime pairing.'}
        if ($matches.Count) {
            foreach ($name in @('runner_file','runner_sha256','runtime_id','conversation_reuse')) {
                $selected | Add-Member -NotePropertyName $name -NotePropertyValue $matches[0].$name -Force
            }
        }
    }
    if ($selected.runner_file -cnotin @('phi-prime','phi-prime-context-matrix-r2') -or $selected.runner_sha256 -cnotmatch '^[a-f0-9]{64}$') {throw 'Invalid resident runner pairing.'}
    return $selected
}
function Set-ResidentState([string]$State,[string]$Message='') {
    Write-JsonFile (Join-Path $script:job 'resident.json') ([pscustomobject]@{
        state=$State;message=$Message;token=$script:request.prime_token;owner_pid=$script:request.owner_pid
        model_id=$script:request.model;resources=$script:primeResources;runtime_id=$script:primeRuntimeId;boot_id=$script:sessionMetadata.boot
        worker_pid=$PID;worker_start_ticks=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks;updated_utc=[DateTime]::UtcNow.ToString('o')
    })
}
function Get-PrimingResourceModel($Model) {
    if (!(Test-ImageModel $Model)) {return $Model}
    # Reserve the supported input envelope before keeping a context resident.
    $images=@(1..4 | ForEach-Object {[pscustomobject]@{width=4096;height=4096;bytes=32MB}})
    return Get-VisionResourceModel $Model $images
}
function Start-PrimeNative($BaseModel,$State,$Ready,$Pin) {
    $remoteModel=Prepare-ChatSession $Ready $BaseModel $State
    if (Test-ImageModel $BaseModel) { $script:remoteProjector=Assert-PreparedProjector $Ready $BaseModel $State }
    $script:primeThreads=Get-PerformanceThreads $BaseModel $script:health.profile $Pin (Get-ThreadChoice $script:health.profile $BaseModel $State)
    $script:performance=Get-PerformanceOptions $BaseModel $script:health.profile $Pin $script:primeThreads.prompt
    $envelope=Add-PerformanceReserve (Get-PrimingResourceModel $BaseModel) $script:performance
    $script:primeResources=Get-AutoResourcePlan $envelope $script:health.profile $Ready.resource_metadata (Read-MemorySnapshot $script:preparedMemory) $State
    $script:primeModel=Get-ContextModel $envelope $script:health.profile $script:primeResources.context_tokens $Ready.resource_metadata $script:primeResources.batch_tokens
    $script:request.batch=$script:primeResources.batch_tokens
    Set-ResidentState 'priming' 'Priming model...'
    Require-CardMemory $script:primeModel -Snapshot $script:preparedMemory
    $script:preparedMemory=''
    $remote=$script:preparedRemote; $script:preparedRemote=''
    $script:primeRemote=$remote
    $archive=Join-Path $script:data ('priming-runtime/payload-'+$Pin.sha256+'/'+$Pin.file)
    if ($Pin.file -cne 'prime-7120P.tar' -or $Pin.sha256 -cnotmatch '^[a-f0-9]{64}$' -or
        !(Test-Path -LiteralPath $archive -PathType Leaf) -or (Get-Item -LiteralPath $archive).Length -ne $Pin.bytes) {throw 'The pinned priming runtime is missing or changed. Install this version from its complete Windows ZIP.'}
    # Setup verified the pinned asset. Load and re-prime reuse its identity and size.
    $settings=Join-Path $script:job 'prime-settings.sh'
    $values=[ordered]@{
        LOCK_TOKEN=$script:cardLockToken; SOURCE_COMMIT=$script:cfg.source_commit
        RUNTIME_FAMILY='modern-knc'; MODERN_RUNTIME_ID=$State.modern_runtime_id; MODERN_SOURCE_COMMIT=$State.modern_source_commit; MODERN_ENGINE_VARIANT='shared';MODERN_TEST_MODE='none'
        MODEL_PATH=$remoteModel;MODEL_BYTES=$BaseModel.file_size_bytes;THREADS=$script:primeThreads.generation;PROMPT_THREADS=$script:primeThreads.prompt;CORES=$script:health.cores
        PRIME_RUNNER=$Pin.runner_file;Q6_PANEL8=$script:performance.q6_panel8;F16_CONV=$script:performance.f16_conv;F32_ATTN=$script:performance.f32_attn
        PREDICT=0;BATCH=$script:primeResources.batch_tokens;CONTEXT=$script:primeResources.context_tokens;SEED=$script:cfg.seed;RUN_MODE='generate';MQ_ROWS=$script:performance.mq_rows;MQ_COLS=$script:performance.mq_cols;IMAGE_CACHE_MIB=$script:performance.cache_mib;IMAGE_MAX_TOKENS=$script:performance.image_max_tokens;VISION_THREADS=$script:performance.vision_threads;PERFORMANCE_CAPABLE=$(if ($Pin.PSObject.Properties['performance_capability']) {1} else {0})
        RUNTIME_ADMIT_MIB=$script:primeModel.estimated_peak_runtime_mib;RUNTIME_LIMIT_MIB=([int]$script:health.profile.safe_memory_budget_mib-[int][math]::Ceiling($BaseModel.file_size_bytes/1MB)-$(if ($script:primeModel.PSObject.Properties['extra_resident_mib']) {$script:primeModel.extra_resident_mib} else {0}))
        MEMORY_STOP_MIB=$script:health.profile.available_reserve_mib
        PROJECTOR_PATH=$(if (Test-ImageModel $BaseModel) {$script:remoteProjector} else {'none'})
        PROJECTOR_SHA256=$(if (Test-ImageModel $BaseModel) {$BaseModel.projector.sha256} else {'none'})
        PROJECTOR_BYTES=$(if (Test-ImageModel $BaseModel) {$BaseModel.projector.file_size_bytes} else {0})
    }
    $lines=foreach ($entry in $values.GetEnumerator()) {
        if ([string]$entry.Value -cnotmatch '^[A-Za-z0-9_./-]+$') {throw 'Invalid priming setting.'}
        "$($entry.Key)='$($entry.Value)'"
    }
    $stops=if ($BaseModel.PSObject.Properties['stop_token_ids']) {$BaseModel.stop_token_ids -join ','} else {''}
    if ($stops -cnotmatch '^([0-9]{1,6}(,[0-9]{1,6}){0,15})?$') {throw 'Invalid stop tokens.'}
    Write-Utf8 $settings (($lines -join "`n")+"`nSTOP_TOKEN_IDS='$stops'`n")
    Send-CardFiles @($archive,$settings,(Join-Path $script:root 'scripts/prime-worker.sh'),(Join-Path $script:root 'scripts/prime-performance.sh'),(Join-Path $script:root 'scripts/engine-llama-cli-v1.sh'),(Join-Path $script:root 'scripts/elf-check.sh'),(Join-Path $script:root 'scripts/memory-info.awk'),(Join-Path $script:root 'scripts/model-map.awk')) ($remote+'/')
    # Setup verified the archive; SCP supplies transport integrity without repeat scans.
    # MPSS BusyBox does not consistently include a SHA-256 utility.
    $null=Invoke-Card "set -eu; cd '$remote'; mv prime-settings.sh settings.sh; mkdir prime inputs; test `"`$(LC_ALL=C ls -ln '$($Pin.file)' | awk '{print `$5}')`" = '$($Pin.bytes)'; tar -xf '$($Pin.file)' -C prime; rm '$($Pin.file)'"
    $p=New-Object Diagnostics.Process
    $p.StartInfo.FileName=$script:ssh
    $command="exec '$($State.remote_base)/guard' 86400 $($script:cfg.heartbeat_timeout_seconds) bash '$remote/prime-worker.sh' '$($State.remote_base)' '$remote'"
    $p.StartInfo.Arguments=Join-NativeArguments ($script:sshOptions+@('-T',$script:target,$command))
    $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
    $frames=$null
    try {
        if (!$p.Start()) {throw 'Cannot start priming connection.'}
        $frames=New-Object PhiChat.PrimeFrames($p.StandardOutput.BaseStream)
        $diagnostic=New-Object PhiChat.DiagnosticCapture
        $errorTask=$diagnostic.ReadAsync($p.StandardError)
        $p.StandardInput.WriteLine('health-ok');$p.StandardInput.Flush()
        return [pscustomobject]@{process=$p;frames=$frames;diagnostic=$diagnostic;errorTask=$errorTask;remote=$remote;ready=$false;readyFrame=$null;watch=[Diagnostics.Stopwatch]::StartNew();nextHealth=0.0;nextGuard=0.0}
    } catch {
        try {$p.StandardInput.Close();if (!$p.WaitForExit(5000)) {$p.Kill()}} catch {}
        if ($frames) {$frames.Dispose()};$p.Dispose()
        throw
    }
}
function Stop-PrimeNative($Native) {
    $prior=$script:cleanupMode;$script:cleanupMode=$true
    try {
        $remote=if ($Native) {$Native.remote} else {$script:primeRemote}
        if ($Native) {
            try {$Native.process.StandardInput.Close()} catch {}
            if (!$Native.process.WaitForExit(5000)) { $Native.process.Kill(); $null=$Native.process.WaitForExit(3000) }
            $Native.frames.Dispose()
            try {if ($Native.errorTask.Wait(2000)) {Write-Utf8 (Join-Path $script:job ('prime-'+(Split-Path $Native.remote -Leaf)+'.stderr.txt')) $Native.errorTask.Result}} catch {}
            $Native.process.Dispose()
            try {
                $timing=Invoke-Card "if test -f '$($Native.remote)/report/timing.txt'; then tail -c 65536 '$($Native.remote)/report/timing.txt'; fi"
                Write-Utf8 (Join-Path $script:job ('prime-'+(Split-Path $Native.remote -Leaf)+'.native.txt')) $timing
            } catch {}
        }
        # Include startup failures before a process handle was returned.
        if ($remote) {
            $null=Invoke-Card "for d in '$remote'/inputs/*; do case `"`$d`" in '$remote'/inputs/*) rm -f `"`$d/prompt.txt`" `"`$d/image-0.png`" `"`$d/image-1.png`" `"`$d/image-2.png`" `"`$d/image-3.png`";; esac; done; rm -f '$remote/prime/bin/phi-prime' '$remote/prime/bin/phi-prime-context-matrix-r2' '$remote/prime/lib/libgomp.so.1' '$remote/prime-7120P.tar'"
            $script:primeRemote=''
        }
    } finally { try {Release-CardWorkloadLock} finally {$script:cleanupMode=$prior} }
}
function Complete-PrimeRequest($Active,[string]$State,[string]$Message,$Metrics=$null,[switch]$InvalidateReady) {
    if ($Active.stream) {$Active.stream.Dispose();$Active.stream=$null}
    $status=[pscustomobject]@{state=$State;message=$Message;preserve_ready=(!$InvalidateReady -and $State -in @('cancelled','failed'));progress=$null;result=$Metrics}
    Write-JsonFile (Join-Path $Active.job 'status.json') $status
    if ($State -ceq 'failed') {Write-JsonFile (Join-Path $Active.job 'failure.json') $status}
    Write-JsonFile (Join-Path $Active.job 'prime-finished.json') ([pscustomobject]@{state=$State})
    try {[IO.File]::Delete((Join-Path $Active.job 'prime-input.json'))} catch {}
}
function Send-PrimeRequest($Active,$Native,[switch]$LatestOnly) {
    $prompt=New-ChatPrompt $script:primeModel @($Active.request.messages) $script:cfg.system_prompt 0 -LatestOnly:$LatestOnly -ThinkingDepth (Get-ThinkingDepth $Active.request)
    $Active.prompt=$prompt;$Active.id=[Guid]::NewGuid().ToString('N');$Active.attempt++
    $remote=$Native.remote+'/inputs/'+$Active.id
    $local=Join-Path $Active.job ('prime-send-'+$Active.id)
    $null=New-Item -ItemType Directory -Path $local
    $files=@();$promptPath=Join-Path $local 'prompt.txt';Write-Utf8 $promptPath $prompt.text;$files+=@($promptPath)
    # Keep the resident guard alive and observe this response's Stop flag while
    # synchronous file transfer waits for either SCIF or its SCP fallback.
    $script:transferOwner=[pscustomobject]@{active=$Active;native=$Native;nextHealth=0.0}
    try {
        foreach ($image in @($prompt.images)) {
            $source=Assert-StoredImage $script:data $image
            $path=Join-Path $local ('image-'+($files.Count-1)+'.png')
            Copy-Item -LiteralPath $source -Destination $path;$files+=@($path)
        }
        $null=Invoke-Card "mkdir '$remote'"
        Send-CardFiles $files ($remote+'/')
        $predict=if ($Active.request.PSObject.Properties['output_tokens']) {[int]$Active.request.output_tokens} else {0}
        if ($predict -lt 0 -or $predict -ge $script:primeResources.context_tokens) {Stop-ChatInput 'Reply budget exceeds the primed context.'}
        $count=@($prompt.images).Count
        $null=Invoke-Card "printf 'PHI_PRIME_V1\n$($Active.id)\n$predict\n$count\n' > '$($Native.remote)/request.pending' && mv '$($Native.remote)/request.pending' '$($Native.remote)/request'"
    } catch {
        if (!$_.Exception.Data['PhiChatTransferCancelled']) {throw}
        # The resident loop sees the same cancel file, stops any published
        # request and re-primes through its normal response-cancellation path.
    } finally {
        $script:transferOwner=$null
        foreach ($file in $files) {Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue}
    }
}
function New-PrimeRequest($Envelope,$Native) {
    if ($Envelope.token -cne $script:request.prime_token -or $Envelope.id -cnotmatch '^[a-f0-9]{32}$' -or $Envelope.job -cnotmatch '^job-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$') {throw 'Invalid resident queue entry.'}
    $directory=Join-Path (Join-Path $script:data 'jobs') $Envelope.job
    if ((Get-Item -LiteralPath $directory).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Invalid request directory.'}
    $request=Read-JsonFile (Join-Path $directory 'prime-input.json')
    Assert-PhiJobProtocol $request
    if ($request.action -cne 'Chat' -or $request.owner_pid -ne $script:request.owner_pid -or $request.model -cne $script:request.model -or $request.ready.resident.token -cne $script:request.prime_token) {throw 'Request does not belong to this primed model.'}
    if ($request.PSObject.Properties['session_epoch'] -and $request.session_epoch -cne ($script:health.serial+'/'+$script:sessionMetadata.boot)) {throw 'Card session changed. Reconnect before sending.'}
    return [pscustomobject]@{job=$directory;request=$request;id='';attempt=0;prompt=$null;watch=[Diagnostics.Stopwatch]::StartNew();stream=(New-Object IO.FileStream((Join-Path $directory 'response.txt'),[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite));generated=0;bytes=0L;first=$null;ack=$null;accepted=$null;phase='starting';consumed=0;prefillStart=$null;peakTemperature=$script:health.temperature_c;peakAdditional=0L;minAvailable=[long]::MaxValue}
}
function Update-PrimeRequest($Active,$Native) {
    $sample=$Native.diagnostic.Snapshot
    if ($sample) {
        $Active.peakAdditional=[math]::Max($Active.peakAdditional,$sample.AdditionalKiB)
        $Active.minAvailable=[math]::Min($Active.minAvailable,$sample.AvailableKiB)
    }
    $Active.peakTemperature=[math]::Max($Active.peakTemperature,$script:health.temperature_c)
    $nativeProgress=[pscustomobject]@{Stage=$(if ($Active.phase -ceq 'generating') {'prefill'} else {$Active.phase});Consumed=$Active.consumed;AvailableKiB=$(if ($sample) {$sample.AvailableKiB} else {0});AdditionalKiB=$(if ($sample) {$sample.AdditionalKiB} else {0});SampleSeconds=$Active.watch.Elapsed.TotalSeconds;PrefillSeconds=$(if ($null -ne $Active.prefillStart) {$Active.watch.Elapsed.TotalSeconds-$Active.prefillStart} else {0})}
    Write-JsonFile (Join-Path $Active.job 'live-progress.json') ([pscustomobject]@{stage=$Active.phase;elapsed_seconds=$Active.watch.Elapsed.TotalSeconds;first_byte_seconds=$Active.first;output_bytes=$Active.bytes;native=$nativeProgress;complete=$false;updated_utc=[DateTime]::UtcNow.ToString('o')})
    Write-JsonFile (Join-Path $Active.job 'status.json') ([pscustomobject]@{state='running';message='Responding...';temperature_c=$script:health.temperature_c;thermal_stop_c=$script:health.profile.thermal_stop_c;progress=$null})
}
function Read-PrimeFrame($Frame,$Native,$Active) {
    if ($Frame.Kind -ceq 'READY') {
        if ($Frame.Id -cne ('0'*32) -or $Native.readyFrame) {throw 'Unexpected priming readiness frame.'}
        $ready=$Frame.Text | ConvertFrom-Json
        if ($ready.protocol -ne 1 -or $ready.context -ne $script:primeResources.context_tokens -or $ready.batch -ne $script:primeResources.batch_tokens) {throw 'Native priming allocation differs from the selected resources.'}
        $Native.readyFrame=$ready;return 'ready'
    }
    if (!$Active -or $Frame.Id -cne $Active.id) {throw 'Native response does not match the active request.'}
    switch -CaseSensitive ($Frame.Kind) {
        'ACK' {$Active.ack=$Active.watch.Elapsed.TotalSeconds}
        'STAGE' {if ($Frame.Text -cnotin @('vision','prefill')) {throw 'Invalid native stage.'};$Active.phase=$Frame.Text;$Active.prefillStart=$Active.watch.Elapsed.TotalSeconds}
        'COUNT' {$n=0L;if (![long]::TryParse($Frame.Text,[ref]$n) -or $n -lt 0 -or $n -gt $script:primeResources.context_tokens) {throw 'Invalid token progress.'};$Active.consumed=$n}
        'ACCEPTED' {
            $a=$Frame.Text | ConvertFrom-Json
            if ($a.prompt_tokens -lt 1 -or $a.prompt_positions -lt 1 -or $a.output_tokens -lt 1 -or [long]$a.prompt_positions+$a.output_tokens -gt $script:primeResources.context_tokens -or [long]$a.prompt_tokens+$a.output_tokens -gt $script:primeResources.context_tokens) {throw 'Native prompt budget is invalid.'}
            $Active.accepted=$a
            Write-JsonFile (Join-Path $Active.job 'prompt-budget.json') ([pscustomobject]@{context_tokens=$script:primeResources.context_tokens;reserved_reply_tokens=$a.output_tokens;margin_tokens=64;prompt_budget=($script:primeResources.context_tokens-$a.output_tokens-64);prompt_tokens=$a.prompt_tokens;prompt_positions=$a.prompt_positions;native_counted=$true;omitted_pairs=$Active.prompt.omitted_pairs;image_count=@($Active.prompt.images).Count})
            Write-JsonFile (Join-Path $Active.job 'resource-settings.json') ([pscustomobject]@{threads=$script:primeThreads;batch=$script:primeResources.batch_tokens;context=$script:primeResources.context_tokens;model_sha256=$script:primeModel.sha256;source_commit=$script:cfg.source_commit})
        }
        'TEXT' {
            if (!$Active.accepted) {throw 'Model text arrived before token admission.'}
            $Active.stream.Write($Frame.Data,0,$Frame.Data.Length);$Active.stream.Flush()
            $Active.bytes+=$Frame.Data.Length;$Active.generated++;$Active.phase='generating'
            $Active.consumed=$Active.accepted.prompt_tokens+$Active.generated
            if ($null -eq $Active.first -and $Frame.Data.Length) {$Active.first=$Active.watch.Elapsed.TotalSeconds}
        }
        'REJECTED' {return 'rejected'}
        'DONE' {
            if (!$Active.accepted) {throw 'Native completion arrived before admission.'}
            $m=$Frame.Text | ConvertFrom-Json
            if ($m.generated_tokens -ne $Active.generated -or $m.decode_evals -lt 0 -or $m.decode_evals -gt $m.generated_tokens -or $m.prepare_ms -lt 0 -or $m.prefill_ms -lt 0 -or $m.decode_ms -lt 0 -or $m.reset_ms -lt 0) {throw 'Invalid native completion metrics.'}
            $inputMetrics=Get-PerformancePromptMetrics $m $Active.accepted.prompt_tokens
            $metrics=[pscustomobject]@{model_id=$script:primeModel.id;model_sha256=$script:primeModel.sha256;context=$script:primeResources.context_tokens;batch=$script:primeResources.batch_tokens;generation_threads=$script:primeThreads.generation;prompt_threads=$script:primeThreads.prompt;generation_tokens=$m.generated_tokens;generation_tps=$(if ($m.decode_evals -gt 0 -and $m.decode_ms -gt 0) {1000*$m.decode_evals/$m.decode_ms} else {$null});prompt_tps=$(if ($m.prefill_ms -gt 0) {1000*$inputMetrics.prompt_evaluated_tokens/$m.prefill_ms} else {$null});load_ms=0;preparation_seconds=$Active.ack;native_prepare_seconds=($m.prepare_ms/1000);reset_seconds=($m.reset_ms/1000);first_byte_seconds=$Active.first;inference_wall_seconds=$Active.watch.Elapsed.TotalSeconds;peak_temperature_c=$Active.peakTemperature;peak_additional_rss_mib=($Active.peakAdditional/1024);min_free_mib=($Active.minAvailable/1024);runtime_source_commit=$script:primeState.modern_source_commit;memory_mode='resident_shared_mmap';primed=$true}
            $metrics | Add-Member runtime_id $script:primeRuntimeId
            foreach ($property in $inputMetrics.PSObject.Properties) {$metrics | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value}
            Add-PerformanceMetrics $metrics $m
            Write-JsonFile (Join-Path $Active.job 'resident-metrics.json') $metrics
            Complete-PrimeRequest $Active 'done' '' $metrics
            return 'done'
        }
        default {throw 'Unexpected native frame.'}
    }
    return ''
}
function Invoke-ResidentWorker($Model,$State,$Ready) {
    if ($script:request.prime_token -cnotmatch '^[a-f0-9]{32}$') {throw 'Invalid primed worker identity.'}
    $script:primeRuntimeId='';$script:primeResources=$null;$script:primeState=$State;$script:primeRemote=''
    $native=$null;$active=$null;$nextUpdate=0.0;$failureMessage='Primed worker stopped. Reload the model.'
    $pin=Get-PrimingPayload $Model $State
    if (!$pin) {throw 'Priming is not packaged for this card.'}
    $script:primeRuntimeId=$pin.runtime_id
    $null=New-Item -ItemType Directory -Path (Join-Path $script:job 'inbox')
    try {
        $native=Start-PrimeNative $Model $State $Ready $pin
        while ($true) {
            Assert-JobActive
            if ($native.process.HasExited -or $native.frames.Error -or $native.frames.Complete) {throw ('Primed runtime stopped. '+$native.frames.Error)}
            if ($native.watch.Elapsed.TotalSeconds -ge $native.nextHealth) {
                $null=Read-CardHealth -DuringRun
                $native.process.StandardInput.WriteLine('health-ok');$native.process.StandardInput.Flush()
                $native.nextHealth=$native.watch.Elapsed.TotalSeconds+[int]$script:cfg.poll_seconds
            }
            while ($null -ne ($frame=$native.frames.Pop())) {
                $event=Read-PrimeFrame $frame $native $active
                if ($event -ceq 'done') {$active=$null;Set-ResidentState 'ready'}
                elseif ($event -ceq 'rejected') {
                    if ($active.attempt -lt 2 -and $active.request.messages.Count -gt 1) {Send-PrimeRequest $active $native -LatestOnly}
                    else {Complete-PrimeRequest $active 'failed' 'Your newest message exceeds the available context. Shorten it and retry.';$active=$null;Set-ResidentState 'ready'}
                }
            }
            if (!$native.ready -and $native.readyFrame -and $native.watch.Elapsed.TotalSeconds -ge $native.nextGuard) {
                $guard=(Invoke-Card "if test -f '$($native.remote)/report/priming-guard-ready.txt'; then printf ready; fi").Trim()
                $native.nextGuard=$native.watch.Elapsed.TotalSeconds+1
                if ($guard -ceq 'ready') {$native.ready=$true;Write-JsonFile (Join-Path $script:job 'prime-ready.json') $native.readyFrame;Set-ResidentState 'ready'}
            }
            if (!$native.ready -and $native.watch.Elapsed.TotalMinutes -gt 15) {throw 'Native priming timed out.'}
            if ($active) {
                $cancel=Test-Path -LiteralPath (Join-Path $active.job 'cancel')
                if ($cancel -or $active.watch.Elapsed.TotalSeconds -gt $script:cfg.generation_timeout_seconds) {
                    Set-ResidentState 'priming' 'Re-priming after Stop...'
                    Stop-PrimeNative $native;$native=$null
                    Complete-PrimeRequest $active 'cancelled' 'Response stopped';$active=$null
                    $native=Start-PrimeNative $Model $State $Ready $pin
                } elseif ($active.watch.Elapsed.TotalSeconds -ge $nextUpdate) {
                    Update-PrimeRequest $active $native;$nextUpdate=$active.watch.Elapsed.TotalSeconds+0.25
                }
            }
            if ($native.ready -and !$active) {
                $pending=@(Get-ChildItem -LiteralPath (Join-Path $script:job 'inbox') -Filter '*.json' -File | Sort-Object Name | Select-Object -First 1)
                if ($pending.Count) {
                    $envelope=Read-JsonFile $pending[0].FullName
                    Remove-Item -LiteralPath $pending[0].FullName -Force
                    $active=New-PrimeRequest $envelope $native;$nextUpdate=0.0
                    if (Test-Path -LiteralPath (Join-Path $active.job 'cancel')) {Complete-PrimeRequest $active 'cancelled' 'Response stopped';$active=$null}
                    else {
                        try {Update-PreparationHealth;Send-PrimeRequest $active $native;Set-ResidentState 'busy'}
                        catch {
                            if (!$_.Exception.Data.Contains('PhiChatInput')) {throw}
                            Complete-PrimeRequest $active 'failed' $_.Exception.Message;$active=$null;Set-ResidentState 'ready'
                        }
                    }
                }
            }
            Start-Sleep -Milliseconds 40
        }
    } catch {
        $failureMessage=$_.Exception.Message
        throw
    } finally {
        try {Stop-PrimeNative $native}
        finally {
            if ($active) {Complete-PrimeRequest $active 'failed' $failureMessage -InvalidateReady}
            if ($script:sessionMetadata) {Set-ResidentState 'closed' 'Model unloaded'}
            Write-JsonFile (Join-Path $script:job 'finished.json') ([pscustomobject]@{cleanup_confirmed=$script:cleanupConfirmed})
        }
    }
}
