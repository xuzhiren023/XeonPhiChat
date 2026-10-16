Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Connection.ps1')
. (Join-Path $PSScriptRoot 'Phase3Core.ps1')
. (Join-Path $PSScriptRoot 'Hardware.ps1')
. (Join-Path $PSScriptRoot 'Memory.ps1')
. (Join-Path $PSScriptRoot 'Context.ps1')
. (Join-Path $PSScriptRoot 'Images.ps1')
. (Join-Path $PSScriptRoot 'Vision.ps1')
. (Join-Path $PSScriptRoot 'Thinking.ps1')
. (Join-Path $PSScriptRoot 'Forecast.ps1')
. (Join-Path $PSScriptRoot 'CapturedProcess.ps1')
if (!('PhiChat.LiveCapture' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'LiveText.cs') }
if (!('PhiChat.StateFiles' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'StateFiles.cs') }

function Read-JsonFile([string]$Path) { [PhiChat.StateFiles]::ReadText($Path) | ConvertFrom-Json }
function Write-JsonFile([string]$Path, $Value) {
    [PhiChat.StateFiles]::WriteText($Path,($Value | ConvertTo-Json -Depth 12))
}
function Test-ModernTextModel($Model) {
    return ($Model.architecture -cin @('lfm2','lfm2moe','qwen3') -or ($Model.PSObject.Properties['runtime_family'] -and $Model.runtime_family -ceq 'modern-knc' -and $Model.architecture -ceq 'llama'))
}
function Test-SharedRuntimeModel($Model) {
    return ((Test-ModernTextModel $Model) -and $Model.PSObject.Properties['required_runtime_feature'] -and $Model.required_runtime_feature -cin @('shared-multi-quant-v1','knc-text-image-r1'))
}
function Get-ModelEngineVariant($Model) {
    Assert-ModelRuntime $Model
    if (Test-SharedRuntimeModel $Model) { return 'shared' }
    if (Test-ModernTextModel $Model) { return 'standard' }
    return 'historical'
}
function Get-ModelProfile([string]$Root,[string]$Name) {
    if ($Name -notmatch '^[a-z0-9][a-z0-9_.-]*$') { throw 'Invalid model profile name.' }
    $m = Read-JsonFile (Join-Path $Root ('config\models\' + $Name + '.yaml'))
    if ($m.revision -notmatch '^[0-9a-f]{40}$' -or $m.sha256 -notmatch '^[0-9a-f]{64}$' -or
        $m.filename -notmatch '^[A-Za-z0-9_.-]+\.gguf$' -or $m.id -notmatch '^[a-z0-9][a-z0-9_.-]+$' -or
        $m.repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -or
        $m.chat_template -notin @('zephyr','chatml','gguf_metadata') -or
        $m.architecture -notin @('llama','lfm2','lfm2moe','qwen3') -or
        $m.memory_mode -cne 'shared_mmap') { throw 'Invalid pinned model profile or unsupported memory mode.' }
    $modern=($m.architecture -in @('lfm2','lfm2moe','qwen3') -or (Test-ModernTextModel $m))
    if ($modern) {
        if (!$m.PSObject.Properties['runtime_family'] -or $m.runtime_family -cne 'modern-knc' -or
            ($m.chat_template -cne 'gguf_metadata' -and !($m.id -ceq 'tinydolphin-2.8-1.1b-q5_k_m' -and $m.chat_template -ceq 'chatml')) -or $m.schema_version -ne 3 -or
            $m.required_source_commit -notin @('de7fa0a3c6a2e1b4cd9f22eb8d6bf5b12dbdb63b','6783b11fb0889d68d0046176b4cc92ceee1961b0','d57e0e6e4882445bc625aaee47f91db469f9fc22','61e97998bf49c2d425563920b7e83e52b5ae57a6')) { throw 'Invalid modern KNC model profile.' }
    } elseif ($m.chat_template -ceq 'gguf_metadata') { throw 'Legacy model requires its validated chat template.' }
    return $m
}
function Assert-ModelRuntime($Model) {
    if ((($Model.id -ceq 'lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k' -and $Model.architecture -ceq 'lfm2moe') -or
         ($Model.id -ceq 'lfm2.5-vl-3b-q5_k_m' -and $Model.architecture -ceq 'lfm2' -and (Test-ImageModel $Model)) -or
         ($Model.id -ceq 'huihui-step3-vl-10b-abliterated-q5_k_m' -and $Model.architecture -ceq 'qwen3')) -and
        $Model.required_source_commit -ceq '61e97998bf49c2d425563920b7e83e52b5ae57a6' -and
        $Model.required_runtime_feature -ceq 'knc-text-image-r1' -and $Model.availability -ceq 'experimental_native') { return }
    if ($Model.architecture -cin @('lfm2moe','qwen3')) { throw 'This model requires its pinned multimodal runtime profile.' }
    if ((($Model.id -in @('lfm2.5-2.6b-q5_k_m','lfm2.5-2.6b-matrices-q5_k') -and $Model.architecture -cin @('lfm2','lfm2moe')) -or
        ($Model.id -in @('tinydolphin-2.8-1.1b-q5_k_m','llama-3.3-8b-abliterated-q2_k','llama-3.3-8b-abliterated-q5_k_m','llama-3.3-8b-abliterated-matrices-q5_k') -and $Model.architecture -ceq 'llama' -and (Test-ModernTextModel $Model))) -and
        $Model.required_source_commit -cin @('6783b11fb0889d68d0046176b4cc92ceee1961b0','d57e0e6e4882445bc625aaee47f91db469f9fc22') -and
        $Model.availability -ceq 'experimental_native') { return }
    # This release ships the accepted historical worker. Catalog metadata or a
    # caller-supplied ready.json can never authorize a modern model on that worker.
    if (($Model.PSObject.Properties['runtime_family'] -and $Model.runtime_family -cne 'historical-knc') -or
        $Model.architecture -notin @('llama') -or $Model.chat_template -notin @('zephyr','chatml')) {
        throw 'This model needs the modern native KNC runtime. The GCC IMCI kernels accelerate supported dot products; they do not add this model architecture. Load and Send require a validated modern KNC runtime.'
    }
}
function Get-CardSerial([string]$MicText) {
    $m = [regex]::Match($MicText,'(?m)^\s*Device Serial Number\s*:\s*([A-Za-z0-9-]+)\s*$')
    if (!$m.Success) { throw 'Card serial number unavailable; cannot identify the connected card.' }
    return $m.Groups[1].Value
}
function Assert-RemoteBase([string]$Value) {
    if ($Value -notmatch '^/root/knc-phase3-run-[A-Za-z0-9-]+$') { throw 'Invalid accepted card runtime path.' }
}
function Get-ModelChoices([string]$Root,$Profile=$null) {
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $Root 'config/models') -Filter '*.yaml' | Sort-Object Name)) {
        $model=Get-ModelProfile $Root $file.BaseName
        $enabled=$true; $hint='Select this model, click Load model, then Send when ready.'
        if ($model.PSObject.Properties['description']) { $hint=$model.description+' '+$hint }
        if ($null -ne $Profile) {
            try { Assert-ModelBudget $model $Profile }
            catch { $enabled=$false; $hint=$_.Exception.Message }
        }
        $engine=''
        try { $engine=Get-ModelEngineVariant $model }
        catch { $enabled=$false; $hint=$model.description+' '+$_.Exception.Message }
        [pscustomobject]@{name=$file.BaseName;label=([regex]::Replace($model.label,'\s*\([^)]*\)',''));enabled=$enabled;hint=$hint;
            engine_variant=$engine;optimized=[bool]($enabled -and $null -ne $Profile -and $engine -ceq 'shared' -and $model.required_source_commit -ceq '6783b11fb0889d68d0046176b4cc92ceee1961b0' -and $Profile.profile_id -ceq 'xeon-phi-7120p' -and $model.id -ceq 'tinydolphin-2.8-1.1b-q5_k_m')}
    }
}
function New-ModelConversation {
    return [pscustomobject]@{messages=(New-Object Collections.ArrayList);transcript='';draft='';bubbles=(New-Object Collections.ArrayList)}
}
function Get-ModelConversation([hashtable]$Sessions,[string]$Name) {
    if (!$Sessions.ContainsKey($Name)) { $Sessions[$Name]=New-ModelConversation }
    return $Sessions[$Name]
}
function New-ChatPrompt($Model,[object[]]$Messages,[string]$System,[int]$OutputTokens=128,[switch]$LatestOnly,[string]$ThinkingDepth='standard') {
    Assert-ModelRuntime $Model
    if ($OutputTokens -lt 0) { throw 'Invalid output token allocation.' }
    if ($Messages.Count -lt 1 -or $Messages[-1].role -cne 'user') { throw 'The last message must be from the user.' }
    for ($i=0; $i -lt $Messages.Count; $i++) {
        $role = if ($i % 2 -eq 0) { 'user' } else { 'assistant' }
        if ($Messages[$i].role -cne $role -or [string]::IsNullOrWhiteSpace($Messages[$i].content)) { throw 'Invalid chat message order or empty message.' }
    }
    $start = if ($LatestOnly) { $Messages.Count-1 } else { 0 }
    while ($start -lt $Messages.Count-1 -and @($Messages[$start..($Messages.Count-1)] | ForEach-Object { Get-MessageImages $_ }).Count -gt 4) { $start+=2 }
    $images=@($Messages[$start..($Messages.Count-1)] | ForEach-Object { Get-MessageImages $_ })
    if ($images.Count -gt 4) { Stop-ChatInput 'This runtime accepts up to four images per prompt.' }
    if ($images.Count -and !(Test-ImageModel $Model)) { Stop-ChatInput 'This model accepts text only. Choose LFM2.5-VL or Step3-VL for images.' }
    $sb = New-Object Text.StringBuilder
    $effectiveSystem=Get-ThinkingSystem $Model $System $ThinkingDepth
    $entries = @([pscustomobject]@{role='system';content=$effectiveSystem}) + @($Messages[$start..($Messages.Count-1)])
    if ($Model.architecture -ceq 'llama' -and (Test-ModernTextModel $Model) -and $Model.chat_template -ceq 'gguf_metadata') {
        # Pinned checkpoint text-only Jinja defaults: no tools and fixed date.
        $null=$sb.Append("<|begin_of_text|><|start_header_id|>system<|end_header_id|>`n`nCutting Knowledge Date: December 2023`nToday Date: 30 Dec 2025`n`n"+$System.Trim()+'<|eot_id|>')
        foreach ($e in @($Messages[$start..($Messages.Count-1)])) {
            $null=$sb.Append("<|start_header_id|>$($e.role)<|end_header_id|>`n`n"+([string]$e.content).Trim()+'<|eot_id|>')
        }
        $null=$sb.Append("<|start_header_id|>assistant<|end_header_id|>`n`n")
    } else {
    if ($Model.architecture -cin @('lfm2','lfm2moe')) { $null=$sb.Append('<|startoftext|>') }
    foreach ($e in $entries) {
        $content=([string]$e.content).Replace('<__media__>','< media >')
        if ($e.role -ceq 'user') { $content=('<__media__>' * @(Get-MessageImages $e).Count)+$content }
        if ($Model.architecture -cin @('lfm2','lfm2moe','qwen3')) {
            if ($e.role -ceq 'system' -and !$content) { continue }
            if ($e.role -ceq 'assistant' -and $content.Contains('</think>')) { $content=$content.Substring($content.LastIndexOf('</think>',[StringComparison]::Ordinal)+8).Trim() }
        }
        if ($Model.chat_template -eq 'zephyr') { $null=$sb.Append("<|$($e.role)|>`n$content</s>`n") }
        else { $null=$sb.Append("<|im_start|>$($e.role)`n$content<|im_end|>`n") }
    }
    if ($Model.chat_template -eq 'zephyr') { $null=$sb.Append("<|assistant|>`n") }
    else { $null=$sb.Append("<|im_start|>assistant`n") }
    if ($Model.architecture -ceq 'lfm2' -and (!$Model.PSObject.Properties['thinking_prefix'] -or $Model.thinking_prefix)) { $null=$sb.Append('<think>') }
    if ($Model.architecture -ceq 'qwen3') { $null=$sb.Append("<think>`n") }
    }
    $text = $sb.ToString()
    if ($text.IndexOf([char]0) -ge 0) { Stop-ChatInput 'The message contains a NUL character. Remove it and send again.' }
    $bytes=[Text.Encoding]::UTF8.GetByteCount($text)
    if ($bytes -gt 262144) {
        if (!$LatestOnly -and $Messages.Count -gt 1) { return New-ChatPrompt $Model $Messages $System $OutputTokens -LatestOnly -ThinkingDepth $ThinkingDepth }
        Stop-ChatInput 'The newest message exceeds the 256 KiB input safety limit. Split it into smaller messages.'
    }
    # Bytes are only a sufficient-fit shortcut for these byte-fallback
    # tokenizers. Long text is counted by the actual KNC tokenizer, not rejected.
    return [pscustomobject]@{text=$text;images=$images;omitted_pairs=($start/2);utf8_upper_bound=($bytes+1)}
}
function Assert-ModelRuntimeFeatures($Model,$State) {
    if ($Model.PSObject.Properties['required_runtime_feature'] -and
        (!$State -or !$State.PSObject.Properties['modern_features'] -or $Model.required_runtime_feature -cnotin $State.modern_features)) {
        throw 'This model needs the supplied shared multi-quant runtime. Click Restore runtime, then Load model.'
    }
}
function Get-ThreadChoice($Profile,$Model=$null,$State=$null) {
    if ($Model -and (Test-ModernTextModel $Model)) {
        $t=if ($Profile.profile_id -ceq 'xeon-phi-3120a') { 168 } else { 180 }
        $prompt=$t; $rows=4
        # Export r4 was compared natively at this setting on TinyDolphin/7120P.
        # Other models keep a conservative policy, not an inherited speed claim.
        if ($Model.required_source_commit -ceq '6783b11fb0889d68d0046176b4cc92ceee1961b0' -and $Profile.profile_id -ceq 'xeon-phi-7120p' -and $Model.id -ceq 'tinydolphin-2.8-1.1b-q5_k_m' -and (Test-SharedRuntimeModel $Model)) {
            $prompt=120; $rows=8
        }
        if ($t -notin $Profile.thread_candidates -or $prompt -notin $Profile.thread_candidates) { throw 'Modern runtime profile has no matching worker setting.' }
        return [pscustomobject]@{generation=$t;prompt=$prompt;mq_rows=$rows;mode='Modern'}
    }
    $values = @($Profile.thread_candidates | ForEach-Object { [int]$_ })
    $t=($values | Measure-Object -Maximum).Maximum
    if ($t -lt 1) { throw 'Hardware profile has no inference thread count.' }
    return [pscustomobject]@{generation=[int]$t;prompt=[int]$t;mq_rows=4;mode='Full'}
}
function New-TransferProgress([string]$Stage,[long]$Completed,[long]$Total,[double]$ElapsedSeconds,[switch]$Complete) {
    if ($Total -le 0 -or $Completed -lt 0) { throw 'Invalid transfer byte counts.' }
    $bytes=[math]::Min($Completed,$Total)
    $ceiling=if ($Complete) { 100 } else { 99 }
    $percent=[int][math]::Min($ceiling,[math]::Floor(100.0*$bytes/$Total))
    $rate=if ($ElapsedSeconds -gt 0) { $bytes/$ElapsedSeconds } else { 0 }
    return [pscustomobject]@{stage=$Stage;percent=$percent;bytes=$bytes;total_bytes=$Total;bytes_per_second=$rate;indeterminate=$false}
}
function Assert-ModelReady($Ready,$Model,$State,$Health) {
    Assert-ModelRuntime $Model
    if ($Ready -and $Ready.PSObject.Properties['engine_variant'] -and $Ready.engine_variant -cne (Get-ModelEngineVariant $Model)) {
        throw 'The model runtime pairing changed. Load the model again.'
    }
    foreach ($name in @('model_id','model_sha256','source_commit','serial','remote_base','remote_model')) {
        if ($null -eq $Ready -or $null -eq $Ready.PSObject.Properties[$name]) { throw 'Click Load model before sending a message.' }
    }
    if ($Ready.model_id -cne $Model.id -or $Ready.model_sha256 -cne $Model.sha256 -or
        $Ready.source_commit -cne $State.source_commit -or $Ready.serial -cne $Health.serial -or
        $Ready.remote_base -cne $State.remote_base) { throw 'Model or card changed. Click Load model again.' }
    $normal="$($State.remote_base)/models/$($Model.id).gguf"
    $baseline="$($State.remote_base)/model.gguf"
    if ($Ready.remote_model -cne $normal -and !($Ready.remote_model -ceq $baseline -and $State.PSObject.Properties['model_sha256'] -and $State.model_sha256 -ceq $Model.sha256)) {
        throw 'Prepared model path does not match the selected model. Click Load model again.'
    }
}
function Read-LlamaTiming([string]$Text) {
    $culture=[Globalization.CultureInfo]::InvariantCulture
    $result=[ordered]@{load_ms=$null;prompt_tokens=$null;prompt_tps=$null;generation_tokens=$null;generation_tps=$null}
    foreach ($pair in @(@('prompt','prompt eval time'),@('generation','(?<!prompt )\beval time'))) {
        $m=[regex]::Match($Text,$pair[1]+'\s*=\s*[0-9.]+ ms\s*/\s*(\d+) (?:tokens|runs)\s*\([^\r\n]*,\s*([0-9.]+) tokens per second\)')
        if ($m.Success) { $result[$pair[0]+'_tokens']=[int]$m.Groups[1].Value; $result[$pair[0]+'_tps']=[double]::Parse($m.Groups[2].Value,$culture) }
    }
    $m=[regex]::Match($Text,'\bload time\s*=\s*([0-9.]+) ms')
    if ($m.Success) { $result.load_ms=[double]::Parse($m.Groups[1].Value,$culture) }
    return [pscustomobject]$result
}
. (Join-Path $PSScriptRoot 'RuntimeSetup.ps1')
