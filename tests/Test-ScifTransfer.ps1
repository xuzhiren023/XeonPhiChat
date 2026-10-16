#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$script:root=Join-Path $repo 'app'
. (Join-Path $script:root 'lib/ChatCore.ps1')
. (Join-Path $script:root 'lib/Transport.ps1')
$activeCheck=(Get-Item Function:\Assert-JobActive).ScriptBlock
$jobProcess=(Get-Item Function:\Invoke-JobProcess).ScriptBlock
Add-Type -Path (Join-Path $repo 'tools/scif-transfer/ScifSend.cs')
$f=New-Object PhiChat.Scif.Frame
$f.Tag=3;$f.Position=5368709120;$f.Bytes=129;$f.Value=4096;$f.Nonce='a'*32
$read=[PhiChat.Scif.Frame]::Decode($f.Encode())
if ($read.Position -ne 5368709120 -or $read.Nonce -cne ('a'*32)) {throw 'Large-file wire values truncated.'}
[PhiChat.Scif.Frame]::CheckWindow($read,5368709120,5368709249)
$read.Value=4097;$rejected=$false
try {[PhiChat.Scif.Frame]::CheckWindow($read,5368709120,5368709249)} catch {$rejected=$true}
if (!$rejected) {throw 'Unaligned remote window accepted.'}
Write-Output 'PASS: 64-bit file positions, final partial window and aligned DMA contract'

$scratch=Join-Path ([IO.Path]::GetTempPath()) ('phichat-scif-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $scratch
$script:job=$scratch;$script:cleanupMode=$false;$script:operatorCancelled=$false
$script:cardLockOwned=$true;$script:cardLockToken='a'*32
$script:ssh='mock-ssh';$script:scp='mock-scp';$script:sshOptions=@();$script:scpMode=@();$script:target='fixture.invalid'
$script:events=New-Object Collections.Generic.List[string]
$script:scenario='success';$script:scifUnavailable=$false
function Get-ScifTransferPayload {return [pscustomobject]@{sender='mock-sender';receiver='mock-receiver'}}
function Read-CardHealth {param([switch]$DuringRun); $script:events.Add('health')}
function Update-LoadTemperature {if ($script:scenario -ceq 'thermal') {throw 'Temperature too high.'}}
function Assert-JobActive {if ($script:operatorCancelled) {throw 'Stopped by operator.'}}
function Set-LoadProgress {param($Stage,$Bytes,$Total,$ElapsedSeconds,[switch]$Complete)}
function Set-JobStatus {param($Message)}
function Invoke-Card {param($Command);$script:events.Add('control');return ''}
function Start-ScifReceiver($Transfer,[int]$Port) {
    $script:events.Add('receiver')
    if ($Port -ne 22000) {throw 'Port not read from host SCIF listener.'}
    $p=[pscustomobject]@{HasExited=$true;ExitCode=0;StandardInput=(New-Object IO.StringWriter)}
    $p | Add-Member ScriptMethod WaitForExit {param($Milliseconds);return $true}
    $Transfer.process=$p;$Transfer.started=$true
}
function Close-ScifReceiver($Transfer) {
    $script:events.Add('cleanup')
    if ($script:scenario -ceq 'cleanup-failed') {throw 'cleanup unconfirmed'}
    if ($script:scenario -ceq 'receiver-fatal') {$Transfer.receiverExit=43}
}
function Invoke-JobProcess {param($Exe,$Arguments,$Seconds,$OutputPath,[switch]$Guarded,$OnTick)
    if ($Exe -ceq 'mock-scp') {return ''}
    if ($Exe -cne 'mock-sender') {throw 'Unexpected process; hardware calls prohibited.'}
    $script:events.Add('sender')
    $path=$Arguments[3]
    Write-JsonFile $path ([pscustomobject]@{state='waiting';port=22000;bytes=0;category=''})
    & $OnTick 0
    switch ($script:scenario) {
        'stop' {$script:operatorCancelled=$true;throw 'stopped'}
        'fatal' {Write-JsonFile $path ([pscustomobject]@{state='failed';port=22000;bytes=0;category='fatal'});throw 'peer identity mismatch'}
        'success' {Write-JsonFile $path ([pscustomobject]@{state='complete';port=22000;bytes=5368709249;category=''})}
        default {throw 'SCIF transport unavailable'}
    }
    return ''
}
try {
    foreach ($mode in @('success','fallback','fatal','receiver-fatal','stop','thermal','cleanup-failed')) {
        $script:scenario=$mode;$script:events.Clear();$script:operatorCancelled=$false;$script:scifUnavailable=$false
        $answer=$null;$failed=$false
        try {$answer=Try-SendScifFile 'fixture.gguf' '/root/knc-phase3-run-fixture/models/fixture.gguf.part' 5368709249} catch {$failed=$true}
        if ($mode -ceq 'success') {if ($failed -or !$answer) {throw 'DMA success was not accepted.'}}
        elseif ($mode -ceq 'fallback') {if ($failed -or $answer -or !$script:scifUnavailable) {throw 'Unavailable SCIF did not select fallback.'}}
        elseif (!$failed -or $script:scifUnavailable) {throw ('Unsafe SCP restart after '+$mode)}
        if (!$script:events.Contains('cleanup')) {throw ('Receiver cleanup missing: '+$mode)}
        Write-Output ('PASS: SCIF '+$mode)
    }
    # Verify the real model wrapper selects fallback exactly once after a clean transport failure.
    $script:scenario='fallback';$script:operatorCancelled=$false;$script:scifUnavailable=$false;$script:scpCopies=0
    function Send-ModelFileScp {param($LocalPath,$RemotePath,$TotalBytes);$script:scpCopies++}
    Send-ModelFile 'fixture.gguf' '/root/knc-phase3-run-fixture/models/fixture.gguf.part' 5368709249
    if ($script:scpCopies -ne 1) {throw 'SCP fallback missing or repeated.'}
    Write-Output 'PASS: model wrapper retries once through SCP after confirmed cleanup'
    $retired=Read-JsonFile (Join-Path $script:root 'config/retired-models/step3-vl-10b-q5_k_m.yaml')
    $new=Get-ModelProfile $script:root 'huihui-step3-vl-10b-abliterated-q5_k_m'
    if ($retired.id -ceq $new.id -or $retired.filename -ceq $new.filename -or $retired.sha256 -ceq $new.sha256) {throw 'Huihui aliases official weights.'}
    $entry=[pscustomobject]@{path='/root/knc-phase3-run-fixture/models/step3-vl-10b-q5_k_m.gguf';bytes=$retired.file_size_bytes;identity=$retired.sha256}
    if ((Get-CacheModel $entry @($new,$retired) ([pscustomobject]@{remote_base='/root/knc-phase3-run-fixture'})).id -cne $retired.id) {throw 'Old Step3 cache cannot be reclaimed.'}
    if (Test-Path -LiteralPath (Join-Path $script:root 'config/models/step3-vl-10b-q5_k_m.yaml')) {throw 'Official Step3 still selectable.'}
    Write-Output 'PASS: Huihui distinct identity; retired official cache recognized but absent from picker'
    # A primed picture send keeps its original guard alive and can stop before
    # the request is published. Exercise the real check and process boundary.
    Set-Item Function:\Assert-JobActive $activeCheck
    $script:scenario='success';$script:request=[pscustomobject]@{owner_pid=0}
    $writer=New-Object IO.StringWriter
    $native=[pscustomobject]@{watch=[Diagnostics.Stopwatch]::StartNew();process=[pscustomobject]@{HasExited=$false;StandardInput=$writer};remote=('/root/knc-chat-'+('b'*32))}
    $activeJob=Join-Path $scratch 'active-response';$null=New-Item -ItemType Directory -Path $activeJob
    $active=[pscustomobject]@{job=$activeJob;request=[pscustomobject]@{messages=@()};id='';attempt=0;prompt=$null}
    $script:transferOwner=[pscustomobject]@{active=$active;native=$native;nextHealth=0.0}
    Assert-JobActive;Assert-JobActive
    if ($writer.ToString().Trim() -cne 'health-ok') {throw 'Resident transfer heartbeat missing or repeated.'}
    $script:processIndex=0;$script:activity='offline cancellation fixture'
    $tick={param($Elapsed);Write-Utf8 (Join-Path $active.job 'cancel') 'stop';Assert-JobActive}
    $cancelled=$false
    try { & $jobProcess (Join-Path $PSHOME 'powershell.exe') @('-NoProfile','-Command','Start-Sleep -Seconds 10') 15 -OnTick $tick | Out-Null }
    catch {$cancelled=($_.Exception.Data['PhiChatTransferCancelled'] -eq $true)}
    if (!$cancelled) {throw 'Transfer cancellation was lost across process cleanup.'}
    . (Join-Path $script:root 'lib/Priming.ps1')
    $script:primeModel=[pscustomobject]@{};$script:cfg=[pscustomobject]@{system_prompt='fixture'}
    function New-ChatPrompt {param($Model,$Messages,$System,$Tokens,[switch]$LatestOnly);return [pscustomobject]@{text='fixture';images=@()}}
    function Send-CardFiles {param($Local,$Remote);Assert-JobActive;throw 'Cancelled picture upload was allowed to continue.'}
    Send-PrimeRequest $active $native
    if ($script:transferOwner) {throw 'Resident transfer context was retained after Stop.'}
    Write-Output 'PASS: primed image transfer heartbeat and Stop survive process cleanup without publishing a request'
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^phichat-scif-[a-f0-9]{32}$') {throw 'Unsafe fixture path.'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Output 'PASS: host-only SCIF fixtures; no uSCIF entry point or Phi contacted'
