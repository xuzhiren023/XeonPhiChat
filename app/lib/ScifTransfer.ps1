# Bulk upload over MPSS SCIF; small bootstrap/control files still use pinned SSH.
function Get-ScifTransferPayload {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {return $null}
    if (!(Get-Variable cardLockOwned -Scope Script -ErrorAction SilentlyContinue) -or !$script:cardLockOwned) {return $null}
    if (Get-Variable scifUnavailable -Scope Script -ErrorAction SilentlyContinue) {if ($script:scifUnavailable) {return $null}}
    if (![Environment]::Is64BitProcess -or !(Test-Path -LiteralPath (Join-Path $env:WINDIR 'System32/uSCIF.dll'))) {return $null}
    $pin=Read-JsonFile (Join-Path $script:root 'config/scif-transfer.json')
    if ($pin.protocol -ne 1) {throw 'Unsupported SCIF transfer protocol.'}
    $paths=@{}
    foreach ($asset in $pin.assets) {
        if ($asset.file -cnotin @('phichat-scif-send.exe','phichat-scif-recv') -or $asset.sha256 -cnotmatch '^[a-f0-9]{64}$') {throw 'Invalid SCIF payload identity.'}
        $path=Join-Path $script:data ('scif-transfer/payload-'+$asset.sha256+'/'+$asset.file)
        # Setup verifies these small helpers once. No image/model hash scan here.
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -ne $asset.bytes) {return $null}
        $paths[$asset.file]=$path
    }
    if ($paths.Count -ne 2) {throw 'Incomplete SCIF payload manifest.'}
    return [pscustomobject]@{sender=$paths['phichat-scif-send.exe'];receiver=$paths['phichat-scif-recv']}
}
function Start-ScifReceiver($Transfer,[int]$Port) {
    if ($Port -lt 1088 -or $Port -gt 65535) {throw 'Invalid local SCIF port.'}
    $command="exec '$($Transfer.remote)/phichat-scif-recv' '$Port' '$($Transfer.nonce)' '$($script:cardLockToken)' '$($Transfer.destination)' '$($Transfer.bytes)' '$($Transfer.remote)'"
    $p=New-Object Diagnostics.Process
    $p.StartInfo.FileName=$script:ssh
    $p.StartInfo.Arguments=Join-NativeArguments ($script:sshOptions+@('-T',$script:target,$command))
    $p.StartInfo.UseShellExecute=$false;$p.StartInfo.CreateNoWindow=$true
    $p.StartInfo.RedirectStandardInput=$true;$p.StartInfo.RedirectStandardOutput=$true;$p.StartInfo.RedirectStandardError=$true
    $Transfer.process=$p
    if (!$p.Start()) {throw 'SCIF receiver connection did not start.'}
    $Transfer.started=$true
    $Transfer.stdout=$p.StandardOutput.ReadToEndAsync();$Transfer.stderr=$p.StandardError.ReadToEndAsync()
    $p.StandardInput.WriteLine('health-ok');$p.StandardInput.Flush()
}
function Close-ScifReceiver($Transfer) {
    # A failed DMA sender has already been terminated by Invoke-JobProcess.
    # Close SSH stdin so the receiver releases its mappings and removes its .part.
    if ($Transfer.started) {
        $p=$Transfer.process
        try {
            $p.StandardInput.Close()
            if (!$p.WaitForExit(5000)) {$p.Kill();$null=$p.WaitForExit(3000)}
            if ($p.HasExited) {$Transfer.receiverExit=$p.ExitCode}
            if ($Transfer.stdout.Wait(2000)) {Write-Utf8 ($Transfer.progress+'.receiver.stdout.txt') $Transfer.stdout.Result}
            if ($Transfer.stderr.Wait(2000)) {Write-Utf8 ($Transfer.progress+'.receiver.stderr.txt') $Transfer.stderr.Result}
        } finally {$p.Dispose()}
    } elseif ($Transfer.process) {$Transfer.process.Dispose()}
    if (!$Transfer.staged) {return}
    # Token/path-scoped cleanup. A stale/reused PID can never authorize killing
    # another process. Wait for the receiver's own 20-second EOF/heartbeat guard.
    $command=@"
set -eu
d='$($Transfer.remote)'
if test -f "`$d/pid"; then
  p=`$(cat "`$d/pid")
  case "`$p" in ''|*[!0-9]*) exit 42;; esac
  i=0
  while test -r "/proc/`$p/cmdline"; do
    if ! tr '\000' '\n' < "/proc/`$p/cmdline" | head -n 1 | grep -Fx "`$d/phichat-scif-recv" >/dev/null; then exit 42; fi
    test "`$i" -lt 25 || exit 42
    sleep 1; i=`$((i+1))
  done
fi
test ! -e "`$d/pid" || rm -f "`$d/pid"
rm -f "`$d/phichat-scif-recv"
rmdir "`$d"
printf clean
"@
    $prior=$script:cleanupMode;$script:cleanupMode=$true
    try {
        $reply=Invoke-JobProcess $script:ssh ($script:sshOptions+@('-T',$script:target,$command.Replace("`r`n","`n"))) 40
        if ($reply.Trim() -cne 'clean') {throw 'SCIF cleanup is not confirmed; reconnect before retrying.'}
    } finally {$script:cleanupMode=$prior}
}
function Try-SendScifFile([string]$LocalPath,[string]$RemotePath,[long]$TotalBytes) {
    $payload=Get-ScifTransferPayload
    if (!$payload) {return $false}
    if ($script:cardLockToken -cnotmatch '^[a-f0-9]{32}$' -or $TotalBytes -le 0 -or
        $RemotePath -cnotmatch '^/root/knc-(?:phase3-run|chat|modern|gcc)-[A-Za-z0-9_./-]+\.part$' -or $RemotePath.Contains('..')) {throw 'Invalid SCIF transfer destination or lease.'}
    Assert-JobActive
    $null=Read-CardHealth -DuringRun
    $nonce=[Guid]::NewGuid().ToString('N')
    $transfer=[pscustomobject]@{nonce=$nonce;remote=('/tmp/phi-chat-scif-'+$nonce);destination=$RemotePath;bytes=$TotalBytes
        progress=(Join-Path $script:job ('scif-'+$nonce+'.json'));process=$null;started=$false;staged=$false;stdout=$null;stderr=$null;receiverExit=$null;nextHealth=0.0;abort=$false}
    $failure=$null; $complete=$false
    try {
        $null=Invoke-Card "umask 077; mkdir '$($transfer.remote)'"
        $transfer.staged=$true
        # Bootstrap is deliberately nonrecursive: sending the SCIF helper does not
        # invoke SCIF again. This small binary uses the installed card libscif.so.0.
        $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+@($payload.receiver,($script:target+':'+$transfer.remote+'/phichat-scif-recv'))) 30
        $null=Invoke-Card "chmod 700 '$($transfer.remote)/phichat-scif-recv'"
        Set-LoadProgress 'Copying via SCIF DMA' 0 $TotalBytes 0
        $tick={
            param([double]$ElapsedSeconds)
            if ($ElapsedSeconds -ge $transfer.nextHealth) {
                try {Update-LoadTemperature} catch {$transfer.abort=$true;throw}
                $transfer.nextHealth=$ElapsedSeconds+5
                if ($transfer.started -and !$transfer.process.HasExited) {$transfer.process.StandardInput.WriteLine('health-ok');$transfer.process.StandardInput.Flush()}
            }
            if (Test-Path -LiteralPath $transfer.progress) {
                $progress=Read-JsonFile $transfer.progress
                if (!$transfer.started -and $progress.state -ceq 'waiting') {Start-ScifReceiver $transfer ([int]$progress.port)}
                if ($progress.state -ceq 'copying') {Set-LoadProgress 'Copying via SCIF DMA' ([long]$progress.bytes) $TotalBytes $ElapsedSeconds}
            }
            if ($transfer.started -and $transfer.process.HasExited -and $transfer.process.ExitCode -ne 0) {throw 'The SCIF receiver stopped before completion.'}
        }
        $null=Invoke-JobProcess $payload.sender @($LocalPath,[string]$TotalBytes,$nonce,$transfer.progress) 900 -OnTick $tick
        if (!$transfer.started -or !$transfer.process.WaitForExit(3000) -or $transfer.process.ExitCode -ne 0) {throw 'SCIF receiver completion is missing.'}
        $progress=Read-JsonFile $transfer.progress
        if ($progress.state -cne 'complete' -or [long]$progress.bytes -ne $TotalBytes) {throw 'SCIF transfer did not acknowledge the complete file.'}
        $complete=$true
    } catch {$failure=$_}
    finally {Close-ScifReceiver $transfer}
    Assert-JobActive # A user Stop or thermal failure must never restart through SCP.
    if ($complete) {return $true}
    if ($transfer.abort -or $script:operatorCancelled -or ($failure -and $failure.Exception.Data['PhiChatTransferAbort'])) {throw $failure}
    # Re-evaluate thermal/card identity before deciding that only transport failed.
    $null=Read-CardHealth -DuringRun
    $fatal=($transfer.receiverExit -eq 43)
    if (Test-Path -LiteralPath $transfer.progress) { $fatal=$fatal -or ((Read-JsonFile $transfer.progress).category -ceq 'fatal') }
    if ($fatal) {throw $failure}
    # Remove only our disposable destination after the receiver is gone.
    $null=Invoke-Card "rm -f '$RemotePath'"
    $script:scifUnavailable=$true
    Write-JsonFile ($transfer.progress+'.fallback.json') ([pscustomobject]@{transport='scp';reason=$failure.Exception.Message;receiver_cleanup_confirmed=$true})
    Set-JobStatus 'SCIF DMA is unavailable; continuing with SCP.'
    return $false
}
