# These checkpoints expose reasoning text, but no native effort API in the
# pinned runner. Depth is a prompt preference, never a token or context cap.
function Test-ThinkingModel($Model) {
    return ($Model.PSObject.Properties['thinking_depth'] -and $Model.thinking_depth -ceq 'prompt')
}
function Get-ThinkingDepth($Value) {
    if (!$Value -or !$Value.PSObject.Properties['thinking_depth']) {return 'standard'}
    $depth=[string]$Value.thinking_depth
    if ($depth -cnotin @('light','standard','extended')) {throw 'Invalid thinking depth.'}
    return $depth
}
function Get-ThinkingSystem($Model,[string]$System,[string]$Depth) {
    if ($Depth -cnotin @('light','standard','extended')) {throw 'Invalid thinking depth.'}
    if ($Depth -ceq 'standard') {return $System}
    if (!(Test-ThinkingModel $Model)) {throw 'This model does not support a thinking depth preference.'}
    $instruction=if ($Depth -ceq 'light') {
        'Reasoning effort: light. Use brief reasoning focused on the essential steps, then give your answer. Avoid unnecessary analysis. Keep the final answer as complete as the request requires.'
    } else {
        'Reasoning effort: extended. Think carefully about difficult parts, check assumptions and verify your conclusion before giving the answer. Keep the final answer focused on the request.'
    }
    return ($System.TrimEnd()+"`n`n"+$instruction).Trim()
}
function Test-PromptStartsThinking($Model) {
    return ($Model.architecture -ceq 'qwen3' -or ($Model.architecture -ceq 'lfm2' -and (!$Model.PSObject.Properties['thinking_prefix'] -or $Model.thinking_prefix)))
}
