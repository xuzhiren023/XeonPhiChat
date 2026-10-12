# Estimates are local arithmetic, never an additional model load or card scan.
function Get-ChatForecast($Model,$Profile,[int]$ContextTokens,[int]$OutputTokens,[object[]]$Messages,[string]$System,$Snapshot=$null) {
    $prompt=New-ChatPrompt $Model $Messages $System $OutputTokens
    $budget=Get-PromptBudget $ContextTokens $OutputTokens
    $selected=$null; $problem=''
    try { $selected=Get-ContextModel $Model $Profile $ContextTokens } catch { $problem=$_.Exception.Message }
    # The same context-specific envelope is used for admission. It includes the
    # full allocated KV cache, compute buffers and metadata; do not add KV twice.
    $runtime=[long]$Model.estimated_peak_runtime_mib
    if ($null -ne $selected) { $runtime=[long]$selected.estimated_peak_runtime_mib }
    $weights=[long][math]::Ceiling($Model.file_size_bytes/1MB)
    $reserve=[long]$Profile.available_reserve_mib
    $required=$runtime+$reserve
    $estimated=[long][math]::Ceiling($prompt.text.Length/4.0)
    $live=$null; $headroom=$null
    if ($null -ne $Snapshot) { $live=[math]::Floor($Snapshot.available_kib/1024); $headroom=$live-$required }
    $reason=if ($problem) { $problem } elseif ($null -ne $headroom -and $headroom -lt 0) { "Estimated additional allocation plus reserve exceeds the latest allocatable memory by $(-$headroom) MiB. A fresh on-card check runs before launch." } else { '' }
    return [pscustomobject]@{
        context_tokens=$ContextTokens;prompt_tokens_estimate=$estimated;prompt_utf8_upper_bound=$prompt.utf8_upper_bound
        reply_tokens=$OutputTokens;margin_tokens=64;prompt_budget=$budget
        context_fit_proven=($prompt.utf8_upper_bound -le $budget);needs_native_count=($prompt.utf8_upper_bound -gt $budget)
        estimate_method='formatted UTF-16 characters / 4; approximate, especially for code and non-English text'
        weights_mib=$weights;runtime_full_context_mib=$runtime;total_model_runtime_mib=($weights+$runtime)
        safe_budget_mib=$Profile.safe_memory_budget_mib;additional_required_mib=$required;reserve_mib=$reserve
        last_available_mib=$live;estimated_headroom_mib=$headroom;memory_risk=[bool]$reason;reason=$reason
        note='Weights counted once. Full context allocation includes the reserved reply; runtime estimate is not a guarantee. Live guards remain active.'
    }
}
