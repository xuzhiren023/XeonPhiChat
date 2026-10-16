#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/Priming.ps1')
. (Join-Path $AppRoot 'lib/JobProtocol.ps1')
function Check([bool]$Value,[string]$Message) {if (!$Value) {throw "FAIL: $Message"};Write-Output "PASS: $Message"}
function Reject([scriptblock]$Code,[string]$Message) {$bad=$false;try {& $Code} catch {$bad=$true};Check $bad $Message}
$null=New-Item -ItemType Directory -Path $Scratch -Force
$script:root=$AppRoot
$script:primeRuntimeId='knc-decode3-fixture'
$script:health=[pscustomobject]@{profile=[pscustomobject]@{profile_id='xeon-phi-7120p'}}
$runtime=[pscustomobject]@{modern_source_commit='61e97998bf49c2d425563920b7e83e52b5ae57a6';modern_runtime_id='phichat142-modern-910493bed33a64fd'}
foreach ($file in Get-ChildItem (Join-Path $AppRoot 'config/models') -Filter '*.yaml') {
    $model=Read-JsonFile $file.FullName
    $payload=Get-PrimingPayload $model $runtime
    Check ($payload.file -ceq 'prime-7120P.tar') ('pinned resident runner selected for '+$model.id)
}
$script:health.profile.profile_id='xeon-phi-3120a'
& {
    $step=Get-ModelProfile $AppRoot 'huihui-step3-vl-10b-abliterated-q5_k_m'
    $profile=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
    $pin=(Read-JsonFile (Join-Path $AppRoot 'config/priming-runtime.json')).payloads[0]
    $envelope=Add-PerformanceReserve (Get-PrimingResourceModel $step) (Get-PerformanceOptions $step $profile $pin 240)
    # Metadata from the pinned Step3 GGUF; no model download or card required.
    $metadata=[pscustomobject]@{native_context_tokens=65536;kv_bytes_per_token=147456;activation_bytes_per_token=2359296;attention_heads=32;allocation_supported=$true}
    $plan=Get-AutoResourcePlan $envelope $profile $metadata ([pscustomobject]@{available_kib=8GB/1KB})
    Check ($plan.context_tokens -ge 2048 -and $plan.batch_tokens -ge 1 -and $plan.runtime_mib+$envelope.extra_resident_mib+[math]::Ceiling($step.file_size_bytes/1MB) -le $profile.safe_memory_budget_mib) 'Step3 primes within the unchanged 7120P budget, including four full-size images and the image cache'
    Reject {Get-AutoResourcePlan $envelope $profile $metadata ([pscustomobject]@{available_kib=1GB/1KB})} 'Step3 still rejects insufficient available card RAM'
}
Check ($null -eq (Get-PrimingPayload $model $runtime)) '3120A keeps its existing runtime instead of inheriting 7120P priming'
$script:health.profile.profile_id='xeon-phi-7120p';$runtime.modern_runtime_id='wrong'
Reject {Get-PrimingPayload $model $runtime} 'resident adapter requires the exact base runtime identity'
$id='a'*32
function Read-Frames([byte[]]$Bytes) {
    $stream=New-Object IO.MemoryStream(,$Bytes)
    $reader=New-Object PhiChat.PrimeFrames($stream)
    $frames=New-Object Collections.ArrayList;$watch=[Diagnostics.Stopwatch]::StartNew()
    try {
        do {
            while ($null -ne ($f=$reader.Pop())) {$null=$frames.Add($f)}
            if ($watch.Elapsed.TotalSeconds -gt 5) {throw 'Fixture reader timed out.'}
            Start-Sleep -Milliseconds 5
        } while (!$reader.Complete)
        while ($null -ne ($f=$reader.Pop())) {$null=$frames.Add($f)}
        return [pscustomobject]@{frames=@($frames);error=$reader.Error}
    } finally {$reader.Dispose();$stream.Dispose()}
}
$fake="PHIP1 $id DONE 2`n{}"
$bytes=[Text.Encoding]::UTF8.GetBytes("PHIP1 $id TEXT $($fake.Length)`n$fake"+"PHIP1 $id COUNT 2`n42")
$r=Read-Frames $bytes
Check (!$r.error -and $r.frames.Count -eq 2 -and $r.frames[0].Kind -ceq 'TEXT' -and $r.frames[0].Text -ceq $fake -and $r.frames[1].Text -ceq '42') 'model text cannot impersonate protocol control frames'
$r=Read-Frames ([Text.Encoding]::UTF8.GetBytes("PHIP1 $id TEXT 10`nshort"))
Check ($r.error -like '*Truncated*') 'truncated native output is a failure, never completion'
$r=Read-Frames ([Text.Encoding]::UTF8.GetBytes("PHIP1 $id DONE 9000`n"))
Check ($r.error -like '*Oversized*') 'control frames are bounded'
$r=Read-Frames ([byte[]]([Text.Encoding]::ASCII.GetBytes("PHIP1 $id TEXT 1`n")+@(0xE2)+[Text.Encoding]::ASCII.GetBytes("PHIP1 $id TEXT 2`n")+@(0x82,0xAC)))
$joined=[byte[]]($r.frames[0].Data+$r.frames[1].Data)
Check (!$r.error -and [Text.Encoding]::UTF8.GetString($joined) -ceq ([char]0x20AC).ToString()) 'UTF-8 token fragments remain exact until the UI decoder joins them'

$script:data=$Scratch;$script:job=Join-Path $Scratch 'jobs/job-20261013-120000-aaaaaaaa'
$null=New-Item -ItemType Directory -Path $script:job
$script:request=[pscustomobject]@{prime_token=('b'*32);owner_pid=$PID;model='fixture'}
$script:primeResources=[pscustomobject]@{context_tokens=1024;batch_tokens=64}
$script:sessionMetadata=[pscustomobject]@{boot='fixture-boot'}
$reference=[pscustomobject]@{directory=$script:job;token=$script:request.prime_token;owner_pid=$PID}
Set-ResidentState 'ready'
Check ((Read-ResidentState $Scratch $reference $PID).state -ceq 'ready') 'ready belongs to a live worker and the owning chat window'
Set-ResidentState 'priming' 'Re-priming after Stop...'
Check ((Read-ResidentState $Scratch $reference $PID).state -ceq 'priming') 'background re-priming is distinct from ready'
Stop-ResidentSession $Scratch $reference $PID
Check (Test-Path -LiteralPath (Join-Path $script:job 'cancel')) 'shutdown signals only the owned resident directory'
$bad=$reference.PSObject.Copy();$bad.directory=$Scratch
Reject {Assert-ResidentReference $Scratch $bad $PID} 'resident shutdown cannot target another directory'
Set-ResidentState 'ready'
$saved=Read-JsonFile (Join-Path $script:job 'resident.json');$saved.worker_start_ticks=1
Write-JsonFile (Join-Path $script:job 'resident.json') $saved
Check ((Read-ResidentState $Scratch $reference $PID).state -ceq 'closed') 'a stale or reused worker PID cannot advertise readiness'

# Exercise the actual broker frame handler, including token progress and Stop results.
$script:primeModel=[pscustomobject]@{id='fixture';sha256=('c'*64)}
$script:primeState=[pscustomobject]@{modern_source_commit=('d'*40)}
$script:cfg=[pscustomobject]@{source_commit=('d'*40)}
$script:primeThreads=[pscustomobject]@{generation=2;prompt=2}
$active=[pscustomobject]@{job=$script:job;id=$id;watch=[Diagnostics.Stopwatch]::StartNew();ack=$null;accepted=$null;phase='starting';prefillStart=$null;consumed=0;stream=(New-Object IO.MemoryStream);bytes=0L;generated=0;first=$null;peakTemperature=42;peakAdditional=1024;minAvailable=8192;prompt=[pscustomobject]@{omitted_pairs=0;images=@()}}
$native=[pscustomobject]@{readyFrame=$null}
function Feed([string]$Kind,[string]$Text) {
    $frame=[pscustomobject]@{Id=$id;Kind=$Kind;Text=$Text;Data=[Text.Encoding]::UTF8.GetBytes($Text)}
    Read-PrimeFrame $frame $native $active
}
Reject {Feed 'TEXT' 'too early'} 'text before native token admission is rejected'
$null=Feed 'ACK' '{}'
$null=Feed 'ACCEPTED' '{"prompt_tokens":100,"prompt_positions":100,"output_tokens":860}'
$null=Feed 'STAGE' 'prefill';$null=Feed 'COUNT' '64'
Check ($active.consumed -eq 64) 'prompt ingestion reports native token progress'
$null=Feed 'TEXT' 'hello'
Check ($active.generated -eq 1 -and $active.consumed -eq 101 -and $active.phase -ceq 'generating') 'generation counts native tokens rather than bytes'
$null=Feed 'DONE' '{"prepare_ms":2,"prefill_ms":100,"decode_ms":0,"decode_evals":0,"generated_tokens":1,"reset_ms":3}'
$status=Read-JsonFile (Join-Path $script:job 'status.json')
Check ($status.state -ceq 'done' -and $status.result.primed -and $status.result.load_ms -eq 0 -and $status.result.generation_tokens -eq 1) 'completed requests report warm timings and exact token count'
Complete-PrimeRequest $active 'cancelled' 'Response stopped'
Check ((Read-JsonFile (Join-Path $script:job 'status.json')).preserve_ready) 'Stop preserves conversation readiness while the broker re-primes'
Complete-PrimeRequest $active 'failed' 'Disconnected' -InvalidateReady
Check (!(Read-JsonFile (Join-Path $script:job 'status.json')).preserve_ready) 'lost resident worker requires reloading instead of stale readiness'
& {
    $script:cleanupMode=$false;$script:primeRemote='/root/knc-chat-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';$script:released=$false
    function Invoke-Card {throw 'fixture transport failure'}
    function Release-CardWorkloadLock {$script:released=$true}
    Reject {Stop-PrimeNative $null} 'startup cleanup surfaces a failed transport'
    Check ($script:released -and !$script:cleanupMode) 'startup failure still attempts lease release and restores cancellation checks'
}

# Run the actual broker loop with transport/process edges replaced by fixtures.
& {
    $script:job=Join-Path $Scratch 'jobs/job-20261013-120001-bbbbbbbb';$null=New-Item -ItemType Directory $script:job
    $script:root=$AppRoot;$script:tick=0;$script:starts=0;$script:stops=0;$script:sent=0;$script:observedReprime=$false
    $model=Get-ModelProfile $AppRoot 'lfm2.5-2.6b-q5_k_m'
    $script:request.model=$model.id
    $script:health=[pscustomobject]@{serial='TEST';temperature_c=40;profile=[pscustomobject]@{thermal_stop_c=85}}
    $script:cfg=[pscustomobject]@{source_commit=('d'*40);system_prompt='';generation_timeout_seconds=1800;poll_seconds=5}
    $chat1=Join-Path $Scratch 'jobs/job-20261013-120002-cccccccc';$chat2=Join-Path $Scratch 'jobs/job-20261013-120003-dddddddd'
    $null=New-Item -ItemType Directory $chat1,$chat2
    function Queue-Request([string]$Path,[string]$Text) {
        $r=[pscustomobject]@{action='Chat';model=$script:request.model;owner_pid=$PID;ready=[pscustomobject]@{resident=[pscustomobject]@{token=$script:request.prime_token}};messages=@([pscustomobject]@{role='user';content=$Text});output_tokens=8;session_epoch='TEST/fixture-boot'}
        Write-JsonFile (Join-Path $Path 'prime-input.json') $r
        Write-JsonFile (Join-Path $script:job 'inbox/queue.json') ([pscustomobject]@{token=$script:request.prime_token;id=('e'*32);job=(Split-Path $Path -Leaf)})
    }
    function Get-PrimingPayload {return [pscustomobject]@{fixture=$true;runtime_id='knc-decode3-fixture'}}
    function Start-PrimeNative {
        $script:starts++;$script:primeModel=$model;$script:primeModel.context_tokens=1024
        $script:primeResources=[pscustomobject]@{context_tokens=1024;batch_tokens=64}
        $frames=[pscustomobject]@{Error='';Complete=$false;queue=(New-Object Collections.Queue)}
        $frames | Add-Member ScriptMethod Pop {if ($this.queue.Count) {return $this.queue.Dequeue()};return $null}
        $frames.queue.Enqueue([pscustomobject]@{Id=('0'*32);Kind='READY';Text='{"protocol":1,"context":1024,"batch":64}'})
        $inputWriter=[pscustomobject]@{};$inputWriter | Add-Member ScriptMethod WriteLine {}; $inputWriter | Add-Member ScriptMethod Flush {}
        $script:fixtureNative=[pscustomobject]@{process=[pscustomobject]@{HasExited=$false;StandardInput=$inputWriter};frames=$frames;diagnostic=[pscustomobject]@{Snapshot=$null};remote='/root/fixture';ready=$false;readyFrame=$null;watch=[Diagnostics.Stopwatch]::StartNew();nextHealth=999;nextGuard=0}
        return $script:fixtureNative
    }
    function Stop-PrimeNative {$script:stops++;$script:cleanupConfirmed=$true}
    function Update-PreparationHealth {}
    function Invoke-Card([string]$Command) {
        if ($Command -like '*priming-guard-ready.txt*') {return 'ready'}
        if ($Command -like '*PHI_PRIME_V1*') {
            $script:sent++
            if ($Command -notmatch 'PHI_PRIME_V1\\n([a-f0-9]{32})') {throw 'Missing request identity'}
            $script:sentId=$Matches[1]
        }
        return ''
    }
    function Send-CardFiles([string[]]$Files,[string]$Target) {
        if ($Files.Count -ne 1 -or !(Test-Path -LiteralPath $Files[0])) {throw 'Expected a staged prompt'}
    }
    function Assert-JobActive {
        $script:tick++
        switch ($script:tick) {
            1 {Queue-Request $chat1 'First independent chat'}
            2 {
                foreach ($row in @(@('ACK','{}'),@('ACCEPTED','{"prompt_tokens":10,"prompt_positions":10,"output_tokens":8}'),@('STAGE','prefill'),@('TEXT','answer'),@('DONE','{"prepare_ms":1,"prefill_ms":2,"decode_ms":0,"decode_evals":0,"generated_tokens":1,"reset_ms":1}'))) {
                    $script:fixtureNative.frames.queue.Enqueue([pscustomobject]@{Id=$script:sentId;Kind=$row[0];Text=$row[1];Data=[Text.Encoding]::UTF8.GetBytes($row[1])})
                }
            }
            3 {Queue-Request $chat2 'Stop this request'}
            4 {Write-Utf8 (Join-Path $chat2 'cancel') 'stop'}
            6 {$script:observedReprime=((Read-JsonFile (Join-Path $script:job 'resident.json')).state -ceq 'ready');throw 'fixture finished'}
        }
    }
    $caught=''
    try {Invoke-ResidentWorker $model $script:primeState ([pscustomobject]@{})} catch {$caught=$_.Exception.Message}
    Check ($caught -ceq 'fixture finished') ('broker loop completed intended fixture: '+$caught)
    Check ((Read-JsonFile (Join-Path $chat1 'status.json')).state -ceq 'done' -and $script:sent -eq 2) 'two requests use the broker without a second model loader'
    Check ((Read-JsonFile (Join-Path $chat2 'status.json')).state -ceq 'cancelled' -and $script:starts -eq 2 -and $script:observedReprime) 'Stop confirms cleanup, then re-primes the same selected model'
    Check ((Read-JsonFile (Join-Path $script:job 'finished.json')).cleanup_confirmed -and $script:stops -eq 2) 'broker shutdown releases the resident workload'
}
Write-Output 'PASS: priming protocol and lifecycle fixtures; no hardware commands executed.'
