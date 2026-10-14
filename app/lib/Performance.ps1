# Candidate policy is used only by an explicitly pinned performance-capable runner.
function Get-PerformanceOptions($Model,$Profile,$Pin,[int]$PromptThreads) {
    $off=[pscustomobject]@{cache_mib=0;image_max_tokens=0;vision_threads=$PromptThreads;mq_cols=1;mq_rows=4;reserve_mib=0}
    if (!$Pin.PSObject.Properties['performance_capability']) {return $off}
    if ($Pin.performance_capability -cne 'knc-performance-v1') {throw 'Unknown performance runtime capability.'}
    $config=Read-JsonFile (Join-Path $script:root 'config/performance.json')
    if ($config.schema -ne 1) {throw 'Unknown performance policy schema.'}
    $matches=@($config.profiles | Where-Object {$_.profile -ceq $Profile.profile_id})
    if ($matches.Count -ne 1) {throw 'No unique performance policy for this card.'}
    $policy=$matches[0]
    if ($Profile.profile_id -cne 'xeon-phi-7120p') {throw 'This performance runtime is qualified only for 7120P.'}
    $cores=60
    foreach ($field in @('cache_mib','vision_smt','mq_rows','mq_cols','image_max_tokens')) {
        if ([string]$policy.$field -cnotmatch '^[0-9]+$') {throw ('Invalid performance setting: '+$field)}
    }
    if ($policy.cache_mib -gt 512 -or $policy.vision_smt -notin @(0,1,2,3,4) -or
        $policy.mq_rows -notin @(1,2,4,8) -or $policy.mq_cols -notin @(1,4) -or $policy.image_max_tokens -gt 65536) {throw 'Performance setting out of range.'}
    $vision=if ($policy.vision_smt -eq 0) {$PromptThreads} else {$cores*[int]$policy.vision_smt}
    # The existing affinity setup creates the prompt worker mask. Use a subset;
    # a larger vision pool requires a separately qualified affinity adapter.
    if ($PromptThreads -lt $cores -or $PromptThreads -gt 4*$cores -or $PromptThreads%$cores -ne 0 -or $vision -gt $PromptThreads) {throw 'Vision/prompt worker count exceeds the configured affinity pool.'}
    $isImage=Test-ImageModel $Model
    $cache=if ($isImage) {[int]$policy.cache_mib} else {0}
    return [pscustomobject]@{cache_mib=$cache;image_max_tokens=$(if ($isImage) {[int]$policy.image_max_tokens} else {0});vision_threads=$vision;mq_cols=[int]$policy.mq_cols;mq_rows=[int]$policy.mq_rows;reserve_mib=$(if ($cache) {$cache+2} else {0})}
}
function Add-PerformanceReserve($Model,$Options) {
    $copy=$Model.PSObject.Copy()
    $copy.estimated_peak_runtime_mib+=$Options.reserve_mib
    $copy.minimum_memory_mib+=$Options.reserve_mib
    return $copy
}
function Add-PerformanceMetrics($Metrics,$Native) {
    foreach ($field in @('image_preprocess_ms','image_encode_ms','image_decode_ms','text_prefill_ms','image_chunks','image_cache_hits','image_cache_misses','image_cache_bytes')) {
        if ($Native.PSObject.Properties[$field]) {
            $value=[double]$Native.$field
            if ([double]::IsNaN($value) -or [double]::IsInfinity($value) -or $value -lt 0) {throw 'Invalid native stage metric.'}
            $Metrics | Add-Member -NotePropertyName $field -NotePropertyValue $value -Force
        }
    }
}

function Get-PerformanceThreads($Model,$Profile,$Pin,$Previous) {
    if (!$Pin.PSObject.Properties['performance_capability']) {return $Previous}
    if ($Pin.performance_capability -cne 'knc-performance-v1' -or $Profile.profile_id -cne 'xeon-phi-7120p') {throw 'Unsupported performance worker policy.'}
    # The VL decoder shares the 2.6B LFM architecture. Other architectures keep
    # the previous generation count until separately tuned.
    $generation=if ($Model.architecture -ceq 'lfm2') {120} elseif ($Model.id -cmatch '^llama-3\.3-8b-') {240} else {$Previous.generation}
    return [pscustomobject]@{generation=$generation;prompt=240;mq_rows=8;mode='Decode3'}
}
