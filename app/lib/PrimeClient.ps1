function Assert-ResidentReference([string]$Data,$Reference,[int]$Owner) {
    if (!$Reference -or $Reference.token -cnotmatch '^[a-f0-9]{32}$' -or $Reference.owner_pid -ne $Owner) { throw 'Invalid primed session identity.' }
    $jobs=[IO.Path]::GetFullPath((Join-Path $Data 'jobs')).TrimEnd('\','/')
    $directory=[IO.Path]::GetFullPath([string]$Reference.directory)
    if ((Split-Path $directory -Parent) -ine $jobs -or (Split-Path $directory -Leaf) -cnotmatch '^job-[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$' -or
        !(Test-Path -LiteralPath $directory -PathType Container) -or ((Get-Item -LiteralPath $directory).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Primed session directory is outside this installation.'
    }
    return $directory
}
function Read-ResidentState([string]$Data,$Reference,[int]$Owner) {
    $directory=Assert-ResidentReference $Data $Reference $Owner
    $path=Join-Path $directory 'resident.json'
    if (!(Test-Path -LiteralPath $path)) { return $null }
    $state=Read-JsonFile $path
    if ($state.token -cne $Reference.token -or $state.owner_pid -ne $Owner) { throw 'Primed session identity changed.' }
    if ($state.state -cne 'closed') {
        $worker=Get-Process -Id $state.worker_pid -ErrorAction SilentlyContinue
        if (!$worker -or $worker.StartTime.ToUniversalTime().Ticks -ne [long]$state.worker_start_ticks) {$state.state='closed';$state.message='Primed worker stopped. Reload the model.'}
    }
    return $state
}
function Stop-ResidentSession([string]$Data,$Reference,[int]$Owner) {
    if (!$Reference) {return}
    $directory=Assert-ResidentReference $Data $Reference $Owner
    Write-Utf8 (Join-Path $directory 'cancel') 'shutdown'
}
function Stop-OwnResident([string]$Data,[int]$Owner) {
    $path=Join-Path $Data ('prime-owner-'+$Owner+'.json')
    if (!(Test-Path -LiteralPath $path)) {return}
    $reference=Read-JsonFile $path
    $directory=Assert-ResidentReference $Data $reference $Owner
    Stop-ResidentSession $Data $reference $Owner
    $watch=[Diagnostics.Stopwatch]::StartNew()
    while (!(Test-Path -LiteralPath (Join-Path $directory 'finished.json'))) {
        Assert-JobActive
        $state=Read-ResidentState $Data $reference $Owner
        if ($state -and $state.state -ceq 'closed' -and !(Get-Process -Id $state.worker_pid -ErrorAction SilentlyContinue)) {
            # A killed broker cannot write a receipt. The next Load still must
            # acquire the card's exclusive lease before it can change anything.
            Remove-Item -LiteralPath $path -Force
            return
        }
        if ($watch.Elapsed.TotalSeconds -gt 50) {throw 'The previous primed worker has not confirmed shutdown. Wait for it to stop before loading another model.'}
        Start-Sleep -Milliseconds 100
    }
    $end=Read-JsonFile (Join-Path $directory 'finished.json')
    if (!$end.cleanup_confirmed) {throw 'Previous primed worker cleanup is unconfirmed; preserve its evidence before reloading.'}
    Remove-Item -LiteralPath $path -Force
}
function Start-ResidentSession($Ready) {
    . (Join-Path $script:root 'lib/BackendClient.ps1')
    $token=[Guid]::NewGuid().ToString('N')
    $request=[pscustomobject]@{action='Prime';model=$Ready.model_id;ready=$Ready;batch=0;output_tokens=0;automatic_resources=$true;messages=@();owner_pid=$script:request.owner_pid;connected_serial=$Ready.serial;prime_token=$token}
    $request | Add-Member owner_start_ticks ((Get-Process -Id $request.owner_pid).StartTime.ToUniversalTime().Ticks)
    $worker=Start-PhiBackendJob $script:root $script:data $request
    $reference=[pscustomobject]@{directory=$worker.directory;token=$token;owner_pid=$request.owner_pid}
    Write-JsonFile (Join-Path $script:data ('prime-owner-'+$request.owner_pid+'.json')) $reference
    $watch=[Diagnostics.Stopwatch]::StartNew()
    try {
        Set-JobStatus 'Priming model on Xeon Phi...'
        while (!$worker.process.WaitForExit(100)) {
            Assert-JobActive
            $state=Read-ResidentState $script:data $reference $request.owner_pid
            if ($state -and $state.state -ceq 'ready') {
                $Ready | Add-Member resident $reference -Force
                $Ready.resources=$state.resources
                $Ready | Add-Member boot_id $state.boot_id -Force
                if ($state.PSObject.Properties['runtime_id']) {$Ready | Add-Member priming_runtime_id $state.runtime_id -Force}
                return $Ready
            }
            if ($watch.Elapsed.TotalMinutes -gt 15) {throw 'Model priming did not finish. Review the runtime evidence.'}
        }
        $failure=Read-JsonFile (Join-Path $worker.directory 'status.json')
        throw ('Priming failed: '+$failure.message)
    } catch {
        Stop-ResidentSession $script:data $reference $request.owner_pid
        throw
    } finally { $worker.process.Dispose() }
}
function Invoke-PrimedChat {
    $reference=$script:request.ready.resident
    $directory=Assert-ResidentReference $script:data $reference $script:request.owner_pid
    $state=Read-ResidentState $script:data $reference $script:request.owner_pid
    if (!$state -or $state.state -cne 'ready' -or $state.model_id -cne $script:request.model) {
        throw 'The model is not primed. Wait for priming to finish or Load the model again.'
    }
    $id=[Guid]::NewGuid().ToString('N')
    $inputPath=Join-Path $script:job 'prime-input.json'
    $pending=Join-Path $directory ('inbox/'+$id+'.json')
    Write-JsonFile $inputPath $script:request
    Write-JsonFile $pending ([pscustomobject]@{token=$reference.token;job=(Split-Path $script:job -Leaf);id=$id})
    $watch=[Diagnostics.Stopwatch]::StartNew()
    try {
        while (!(Test-Path -LiteralPath (Join-Path $script:job 'prime-finished.json'))) {
            # The broker confirms cancellation after its native process stops.
            # Do not turn a local cancel-file write into premature success.
            $state=Read-ResidentState $script:data $reference $script:request.owner_pid
            if (!$state -or $state.state -in @('failed','closed') -or (Test-Path -LiteralPath (Join-Path $directory 'finished.json'))) {throw 'Primed worker stopped. Reload the selected model.'}
            if ($watch.Elapsed.TotalSeconds -gt [int]$script:cfg.generation_timeout_seconds+90) {throw 'Primed response did not finish.'}
            if ($script:request.owner_pid -gt 0 -and !(Get-Process -Id $script:request.owner_pid -ErrorAction SilentlyContinue)) {throw 'Chat window closed.'}
            Start-Sleep -Milliseconds 50
        }
        $status=Read-JsonFile (Join-Path $script:job 'status.json')
        if ($status.state -ceq 'failed') {Write-JsonFile (Join-Path $script:job 'failure.json') $status;return 1}
        return 0
    } finally {
        # The broker also removes these files. File.Delete treats an already
        # removed file as success, even when removal overlaps on Windows.
        foreach ($path in @($pending,$inputPath)) {
            try {[IO.File]::Delete($path)} catch {}
        }
    }
}
