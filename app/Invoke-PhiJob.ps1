#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$JobDir)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:preparationWatch=[Diagnostics.Stopwatch]::StartNew()
$script:root=$PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\ChatCore.ps1')
. (Join-Path $PSScriptRoot 'lib\Transport.ps1')
. (Join-Path $PSScriptRoot 'lib\GccRuntime.ps1')
. (Join-Path $PSScriptRoot 'lib\ModernRuntime.ps1')
. (Join-Path $PSScriptRoot 'lib\JobProtocol.ps1')
. (Join-Path $PSScriptRoot 'lib\PrimeClient.ps1')
$script:job=(Resolve-Path -LiteralPath $JobDir).Path
$script:request=$null; $script:health=$null; $script:healthIndex=0; $script:processIndex=0; $script:cleanupMode=$false
$script:cardLockToken=''; $script:cardLockOwned=$false
$script:memoryCheck=$null; $script:cacheSummary=''
$script:preparedRemote=''; $script:preparedMemory=''; $script:sessionMetadata=$null
$script:promptImages=@(); $script:remoteProjector='';
$script:allocationReused=$false; $script:preparationSeconds=0.0
$script:operatorCancelled=$false; $script:cleanupConfirmed=$true
$requestPath=Join-Path $script:job 'request.json'
try {
    Write-Utf8 (Join-Path $script:job 'app-version.txt') ([IO.File]::ReadAllText((Join-Path $script:root 'VERSION')).Trim())
    $script:request=Read-JsonFile $requestPath
    Remove-Item -LiteralPath $requestPath -Force
    Assert-PhiJobProtocol $script:request
    $script:cfg=Read-JsonFile (Join-Path $script:root 'config\app.yaml')
    $script:connection=Read-PhiConnection $script:root
    $script:data=$script:connection.data_dir
    if ($script:cfg.source_commit -notmatch '^[a-f0-9]{40}$' -or
        $script:cfg.poll_seconds -lt 1 -or $script:cfg.poll_seconds -gt 10 -or
        $script:cfg.heartbeat_timeout_seconds -lt 30 -or $script:cfg.heartbeat_timeout_seconds -gt 60 -or
        $script:cfg.generation_timeout_seconds -lt 60 -or $script:cfg.generation_timeout_seconds -gt 86400 -or
        $script:cfg.max_output_tokens -lt 0) { throw 'Unsafe application settings.' }
    if ($script:request.action -notin @('Probe','Health','Load','Chat','Prime','InstallKernel','RollbackKernel','InstallModern','RollbackModern') -or
        $script:request.batch -lt 0) { throw 'Invalid operation or batch size.' }
    if ($script:request.action -in @('Load','Chat','Prime')) { Assert-ModelRuntime (Get-ModelProfile $script:root $script:request.model) }
    # The resident broker already owns the verified runtime and monitors health.
    # Sending only queues this request; it never launches a second model loader.
    if ($script:request.action -ceq 'Chat' -and $script:request.ready -and $script:request.ready.PSObject.Properties['resident']) {
        exit (Invoke-PrimedChat)
    }
    if ($script:request.action -in @('Load','InstallKernel','RollbackKernel','InstallModern','RollbackModern')) {
        Stop-OwnResident $script:data $script:request.owner_pid
    }
    if ($script:connection.card_address -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]*$') { throw 'Invalid card address.' }
    if (!(Test-Path -LiteralPath $script:connection.key_path)) { throw 'Configured SSH key is missing.' }
    $script:profiles=@(Get-ChildItem -LiteralPath (Join-Path $script:root 'config\hardware') -Filter '*.yaml' | ForEach-Object { Read-JsonFile $_.FullName })
    $script:ssh=Get-PhiTool $script:connection 'ssh'; $script:scp=Get-PhiTool $script:connection 'scp'
    $script:target='root@'+$script:connection.card_address
    $script:sshOptions=Get-PhiSshOptions $script:connection
    # Version query is local; exit code/stderr retained as evidence.
    if ($script:request.action -ceq 'Probe') {
        try {
            $raw=Invoke-Card "cat /proc/sys/kernel/random/boot_id; cat /proc/meminfo"
        } catch {
            $offline=($_.Exception.Message -match '(?i)connection (timed out|refused|reset|closed)|no route to host|network is unreachable|host is down')
            Write-JsonFile (Join-Path $script:job 'status.json') ([pscustomobject]@{state='failed';message=$_.Exception.Message;card_offline=$offline})
            exit 1
        }
        $lines=$raw -split "`n",2
        if ($lines.Count -ne 2 -or $lines[0].Trim() -notmatch '^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$') { throw 'Card boot identity unavailable.' }
        $card=Read-CardHealth -DuringRun
        $card | Add-Member boot_id $lines[0].Trim()
        $card | Add-Member memory (Read-MemorySnapshot $lines[1])
        Set-JobStatus 'Connected' 'done' $card
        exit 0
    }
    Set-ScpCompatibility
    if ($script:connection.PSObject.Properties['ssh_path']) { $script:scpMode=@($script:scpMode)+@('-S',$script:ssh) }
    Set-JobStatus 'Checking current card health.'
    $null=Read-CardHealth
    $state=Read-PhiBaseline $script:connection
    Assert-RemoteBase $state.remote_base
    if ($state.source_commit -cne $script:cfg.source_commit) { throw 'Runtime source pin differs from this launcher.' }
    if ($script:request.action -in @('InstallKernel','RollbackKernel')) {
        if ((Invoke-Card 'uname -m').Trim() -cne 'k1om') { throw 'SSH target is not K1OM.' }
        if ($script:request.action -eq 'RollbackKernel') {
            Disable-GccRuntime
            Set-JobStatus 'Original runtime selected. Reconnect and Load model before sending.' 'done'
        } else {
            $selection=Install-GccCardRuntime $state $script:request.runtime_package_dir
            Write-JsonFile (Join-Path $script:job 'gcc-selection.json') $selection
            Set-JobStatus 'GNU IMCI runtime installed and native numerical tests passed. Reconnect and Load model before sending. Token throughput is unmeasured.' 'done'
        }
        exit 0
    }
    # Resolve the modern selection before considering the legacy GCC selection.
    if ($script:request.action -in @('InstallModern','RollbackModern')) {
        if ($script:request.action -eq 'RollbackModern') { Disable-ModernRuntime; Set-JobStatus 'Previous runtime selected. Reconnect and Load model.' 'done' }
        else {
            $package=if ($script:request.PSObject.Properties['runtime_package_dir']) { [string]$script:request.runtime_package_dir } else { '' }
            $selection=Install-ModernCardRuntime $state $package
            Write-JsonFile (Join-Path $script:job 'modern-selection.json') $selection
            Set-JobStatus 'Runtime ready. Load a model to chat.' 'done'
        }
        exit 0
    }
    $modern=Resolve-ModernRuntime $state -RestoreMissing:($script:request.action -in @('Health','Load'))
    if ($modern.PSObject.Properties['modern_runtime_id']) { $state=$modern }
    else { $state=Resolve-GccRuntime $state -RestoreMissing:($script:request.action -eq 'Health') }
    if ($script:request.action -ne 'Chat') {
        if ((Invoke-Card 'uname -m').Trim() -cne 'k1om') { throw 'SSH target is not K1OM; inference stopped.' }
        $exists=(Invoke-Card "if test -x '$($state.remote_base)/guard' && test -x '$($state.remote_base)/llama/main' && test -f '$($state.remote_base)/build-passed.txt'; then cat '$($state.remote_base)/build-passed.txt'; fi").Trim()
        if ($exists -cne $script:cfg.source_commit) { throw 'Accepted runtime is absent on the card. Click Restore runtime, complete its console prompts, then Connect again.' }
    }
    Write-JsonFile (Join-Path $script:job 'hardware.json') $script:health
    Write-JsonFile (Join-Path $script:job 'runtime.json') $state
    if ($script:request.action -eq 'Health') {
        $threads=Get-ThreadChoice $script:health.profile
        $runtimeLabel=if ($state.PSObject.Properties['modern_runtime_id']) { 'modern KNC + GNU IMCI 0.2.1' } elseif ($state.PSObject.Properties['gcc_runtime_id']) { 'GNU IMCI 0.2.1' } else { 'original runtime' }
        Set-JobStatus ("Connected: {0}; {1} cores; {2} MiB GDDR; {3} inference threads; {4}. Select a model, click Load model, then Send." -f $script:health.profile.profile_id,$script:health.cores,$script:health.gddr_mib,$threads.generation,$runtimeLabel) 'done'
        exit 0
    }
    $model=Get-ModelProfile $script:root $script:request.model
    Assert-ModelRuntimeFeatures $model $state
    $state | Add-Member engine_variant (Get-ModelEngineVariant $model) -Force
    Write-JsonFile (Join-Path $script:job 'runtime.json') $state
    if (Test-ModernTextModel $model) {
        if (!(Test-ModernModelSource $model $state)) { throw 'Click Install / restore runtime, wait for success, then Connect and Load model. If the package cache is missing, run Setup.cmd from the extracted Phi Chat installer.' }
        if ($model.PSObject.Properties['required_runtime_version'] -and (!$state.PSObject.Properties['modern_runtime_version'] -or [version]$state.modern_runtime_version -lt [version]$model.required_runtime_version)) { throw 'Install the supplied PhiChat 1.4.1 runtime for checkpoint-specific stop tokens.' }
    }
    Assert-ModelBudget $model $script:health.profile
    if (!$script:request.PSObject.Properties['connected_serial'] -or $script:request.connected_serial -cne $script:health.serial) { throw 'The connected card changed. Click Connect again before loading a model.' }
    if ($script:request.action -eq 'Load') {
        # Stage files, then start a resident worker where the pinned runtime supports it.
        $localProjector=''
        if (Test-ImageModel $model) { $localProjector=Get-LocalModel (Get-ProjectorProfile $model) }
        $localModel=Get-LocalModel $model
        $metadata=Read-ModelResources $localModel $model
        Acquire-CardWorkloadLock
        try {
            $remoteModel=Get-CardModel $model $state $localModel
            $null=Read-CardHealth
            Require-CardMemory $model
            $ready=[pscustomobject]@{model_id=$model.id;model_sha256=$model.sha256;source_commit=$state.source_commit;serial=$script:health.serial;remote_base=$state.remote_base;remote_model=$remoteModel}
            $ready | Add-Member engine_variant (Get-ModelEngineVariant $model)
            $ready | Add-Member modern_source_commit $state.modern_source_commit
            if ($localProjector) {
                $projectorPath=Install-CardProjector $model $state $localProjector
                $ready | Add-Member remote_projector $projectorPath
                $ready | Add-Member projector_sha256 $model.projector.sha256
                $model=Get-VisionResourceModel $model
                Require-CardMemory $model
            }
            $resources=Get-AutoResourcePlan $model $script:health.profile $metadata $script:memoryCheck.snapshot $state
            $ready | Add-Member resource_metadata $metadata
            $ready | Add-Member resources $resources
            Write-JsonFile (Join-Path $script:job 'ready.json') $ready
        } finally { Release-CardWorkloadLock }
        . (Join-Path $script:root 'lib/Priming.ps1')
        if ((!$script:request.PSObject.Properties['prime_model'] -or $script:request.prime_model) -and (Get-PrimingPayload $model $state)) {
            $ready=Start-ResidentSession $ready
            Write-JsonFile (Join-Path $script:job 'ready.json') $ready
        }
        $progress=New-TransferProgress 'Ready on Xeon Phi' $model.file_size_bytes $model.file_size_bytes 0 -Complete
        Set-JobStatus ('Ready on Xeon Phi: '+$model.label+'. Send starts inference. '+$script:cacheSummary) 'done' $ready $progress
        exit 0
    }
    $ready=$null
    if ($script:request.PSObject.Properties['ready']) { $ready=$script:request.ready }
    Assert-ModelReady $ready $model $state $script:health
    if ($script:request.action -ceq 'Prime') {
        . (Join-Path $script:root 'lib/Priming.ps1')
        Invoke-ResidentWorker $model $state $ready
        exit 0
    }
    $threads=Get-ThreadChoice $script:health.profile $model $state
    $automatic=($script:request.PSObject.Properties['automatic_resources'] -and $script:request.automatic_resources)
    # Old explicit requests remain valid for deterministic acceptance tooling.
    if (!$automatic -and $script:request.PSObject.Properties['context_tokens'] -and $script:request.context_tokens -gt 0) {
        $metadata=if ($ready.PSObject.Properties['resource_metadata']) {$ready.resource_metadata} else {$null}
        $model=Get-ContextModel $model $script:health.profile ([int]$script:request.context_tokens) $metadata ([int]$script:request.batch)
    }
    # Send performs no model download, cache eviction or model-weight transfer.
    try {
        $remoteModel=Prepare-ChatSession $ready $model $state
        if ($script:request.PSObject.Properties['session_epoch'] -and $script:request.session_epoch -cne ($script:health.serial+'/'+$script:sessionMetadata.boot)) { throw 'Card session changed. Reconnect before sending.' }
        $requestedImages=@($script:request.messages | ForEach-Object { Get-MessageImages $_ })
        if ($requestedImages.Count -and !(Test-ImageModel $model)) { Stop-ChatInput 'This model accepts text only.' }
        if (Test-ImageModel $model) {
            $script:remoteProjector=Assert-PreparedProjector $ready $model $state
            $selectedInput=New-ChatPrompt $model @($script:request.messages) $script:cfg.system_prompt 0
            $model=Get-VisionResourceModel $model @($selectedInput.images)
        }
        if ($automatic) {
            if (!$ready.PSObject.Properties['resource_metadata']) { Stop-ChatInput 'Reload the model to enable automatic resource allocation.' }
            $resources=Get-AutoResourcePlan $model $script:health.profile $ready.resource_metadata (Read-MemorySnapshot $script:preparedMemory) $state
            $script:request.batch=$resources.batch_tokens
            $script:request.output_tokens=0
            $model=Get-ContextModel $model $script:health.profile $resources.context_tokens $ready.resource_metadata $resources.batch_tokens
        }
        Write-JsonFile (Join-Path $script:job 'resource-settings.json') ([pscustomobject]@{threads=$threads;batch=$script:request.batch;context=$model.context_tokens;model_sha256=$model.sha256;source_commit=$script:cfg.source_commit})
        if ($script:request.PSObject.Properties['modern_test_mode']) {
            if (!(Test-ModernTextModel $model) -or $script:request.modern_test_mode -notin @('validate','trace','scalar','baseline','optimized')) { throw 'Invalid modern validation request.' }
            $prompt=[pscustomobject]@{text="<|startoftext|><|im_start|>user`nCompute 7 plus 5.<|im_end|>`n<|im_start|>assistant`n<think>";omitted_pairs=0}
            if ($model.architecture -ceq 'lfm2' -and $script:request.modern_test_mode -ceq 'validate') { $prompt=[pscustomobject]@{text="<|startoftext|><|im_start|>user`nOne two three.<|im_end|>`n<|im_start|>assistant`n";omitted_pairs=0} }
            if ($model.architecture -ceq 'llama') {
                if ($script:request.modern_test_mode -ceq 'validate') { $prompt=[pscustomobject]@{text='<|begin_of_text|>One two three.';omitted_pairs=0} }
                else { $prompt=New-ChatPrompt $model @([pscustomobject]@{role='user';content='Compute 7 plus 5.'}) '' }
            }
        } else {
        $prompt=Get-CheckedChatPrompt $model $state $remoteModel $threads @($script:request.messages) $script:cfg.system_prompt ([int]$script:request.output_tokens)
        }
        $result=Invoke-Generation $model $state $remoteModel $prompt.text $threads ([int]$script:request.output_tokens) (Join-Path $script:job 'generation')
    } finally { Release-CardWorkloadLock }
    $rate=if ($null -ne $result.metrics.generation_tps) { "$($result.metrics.generation_tps) tokens/s" } else { 'speed unavailable' }
    $first=if ($null -ne $result.metrics.first_byte_seconds) { '{0:N1}s' -f $result.metrics.first_byte_seconds } else { 'unavailable' }
    $prefill=if ($null -ne $result.metrics.prompt_tps) { "$($result.metrics.prompt_tps) tokens/s" } else { 'unavailable' }
    Set-JobStatus ("Completed: preparation {5:N1}s; {0} generation; {1} prompt; first stream byte {2}; {3} threads; shared weights. Older pairs omitted: {4}." -f $rate,$prefill,$first,$threads.generation,$prompt.omitted_pairs,$script:preparationSeconds) 'done' $result.metrics
    exit 0
} catch {
    $problem=$_
    $cancelled=Get-ChatCancellationStatus
    if ($null -ne $cancelled) {
        Write-JsonFile (Join-Path $script:job 'status.json') $cancelled
        exit 0
    }
    try { Write-JobFailure $problem } catch { Write-Host ('Failure evidence write failed: '+$_.Exception.Message) }
    try { Set-JobStatus $problem.Exception.Message 'failed' } catch { Write-Host ('Status write failed: '+$_.Exception.Message) }
    exit 1
} finally {
    Remove-Item -LiteralPath $requestPath -Force -ErrorAction SilentlyContinue
    # If the UI died, discard transient generated chat text as well.
    if ($script:request -and $script:request.owner_pid -gt 0 -and !(Get-Process -Id $script:request.owner_pid -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath (Join-Path $script:job 'response.txt') -Force -ErrorAction SilentlyContinue
    }
}
