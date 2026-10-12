# Resource choices use verified model metadata and current card RAM.
function Stop-ChatInput([string]$Message) {
    $errorObject=New-Object ArgumentException($Message)
    $errorObject.Data['PhiChatInput']=$true
    throw $errorObject
}
function Test-RecoverableChatFailure($Status) {
    return ($null -ne $Status -and $null -ne $Status.PSObject.Properties['preserve_ready'] -and $Status.preserve_ready -eq $true)
}
function Read-ModelResources([string]$Path,$Model) {
    if (!('PhiChat.GgufResources' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'GgufResources.cs') }
    $m=[PhiChat.GgufResources]::Read($Path)
    $arch=[string]$m['general.architecture']
    if ($arch -cne $Model.architecture) { throw 'GGUF architecture differs from the pinned model.' }
    $ctx=[long]$m[$arch+'.context_length']; $layers=[long]$m[$arch+'.block_count']
    $embedding=[long]$m[$arch+'.embedding_length']; $heads=[long]$m[$arch+'.attention.head_count']
    $kvHeads=if ($m.ContainsKey($arch+'.attention.head_count_kv')) { $m[$arch+'.attention.head_count_kv'] } else { $heads }
    if ($ctx -lt 128 -or $ctx -gt [int]::MaxValue -or $layers -lt 1 -or $embedding -lt 1 -or $heads -lt 1) { throw 'GGUF lacks usable context/memory metadata.' }
    if ($kvHeads -is [array]) {
        if ($kvHeads.Count -ne $layers) { throw 'Per-layer KV head counts do not match the block count.' }
        $kvTotal=0L
        foreach ($count in $kvHeads) {
            if ([long]$count -lt 0 -or [long]$count -gt $heads) { throw 'Invalid per-layer KV head count.' }
            $kvTotal+=[long]$count
        }
        if ($kvTotal -lt 1) { throw 'GGUF has no attention KV heads.' }
    } else {
        if ([long]$kvHeads -lt 1 -or [long]$kvHeads -gt $heads) { throw 'Invalid KV head count.' }
        $kvTotal=$layers*[long]$kvHeads
    }
    $key=if ($m.ContainsKey($arch+'.attention.key_length')) { [long]$m[$arch+'.attention.key_length'] } else { $embedding/$heads }
    $value=if ($m.ContainsKey($arch+'.attention.value_length')) { [long]$m[$arch+'.attention.value_length'] } else { $embedding/$heads }
    if ($key -lt 1 -or $value -lt 1) { throw 'Invalid attention dimensions.' }
    # F16 K+V: per-layer metadata distinguishes attention and recurrent blocks.
    $result=[pscustomobject]@{native_context_tokens=[int]$ctx;kv_bytes_per_token=([double]2*$kvTotal*($key+$value));activation_bytes_per_token=([double]16*$embedding*$layers);attention_heads=$heads;allocation_supported=($arch -cne 'lfm2moe')}
    if ($arch -ceq 'lfm2moe') {
        foreach ($field in @('expert_count','expert_used_count','expert_feed_forward_length','leading_dense_block_count','shortconv.l_cache')) {
            if (!$m.ContainsKey($arch+'.'+$field)) { throw ('Missing MoE metadata: '+$field) }
        }
        $experts=[long]$m[$arch+'.expert_count']; $used=[long]$m[$arch+'.expert_used_count']
        $leading=[long]$m[$arch+'.leading_dense_block_count']; $ff=[long]$m[$arch+'.expert_feed_forward_length']
        $cache=[long]$m[$arch+'.shortconv.l_cache']
        if ($experts -lt 1 -or $used -lt 1 -or $used -gt $experts -or $leading -lt 0 -or $leading -ge $layers -or $ff -lt 1 -or $cache -lt 1) { throw 'Invalid MoE metadata.' }
        $result.activation_bytes_per_token=$null
        $result | Add-Member expert_count $experts
        $result | Add-Member experts_per_token $used
        $result | Add-Member allocation_reason 'MoE routing, expert scratch and recurrent state need a validated native memory profile. Active experts do not reduce resident weight bytes.'
    }
    return $result
}
function Assert-ResourceArchitecture($Model) {
    if ($Model.architecture -ceq 'lfm2moe') { Stop-ChatInput 'LFM2-MoE memory allocation is unavailable until its KNC runtime and memory profile are validated.' }
}
function Get-ResourceRuntimeMiB($Model,$Metadata,[int]$Context,[int]$Batch) {
    Assert-ResourceArchitecture $Model
    # Keep the entire baseline envelope; add cache growth and prefill buffers.
    $cache=[math]::Max(0,$Context-[int]$Model.context_tokens)*$Metadata.kv_bytes_per_token/1MB
    $compute=$Batch*($Metadata.activation_bytes_per_token+8.0*$Metadata.attention_heads*$Context)/1MB
    return [long][math]::Ceiling($Model.estimated_peak_runtime_mib+$cache+$compute)
}
function Get-AutoResourcePlan($Model,$Profile,$Metadata,$Snapshot,$State=$null) {
    Assert-ResourceArchitecture $Model
    Assert-ModelBudget $Model $Profile
    if ($null -eq $Metadata -or $null -eq $Snapshot) { Stop-ChatInput 'Load the model to read its context capacity and available card memory.' }
    $weights=[math]::Ceiling($Model.file_size_bytes/1MB)
    $budget=[math]::Min(($Profile.safe_memory_budget_mib-$weights),([math]::Floor($Snapshot.available_kib/1024)-$Profile.available_reserve_mib))
    $target=(Get-ThreadChoice $Profile $Model $State).prompt
    $batch=1
    while ($batch*2 -le $target) { $batch*=2 }
    while ($batch -gt 1 -and (Get-ResourceRuntimeMiB $Model $Metadata 128 $batch) -gt $budget) { $batch=[int]($batch/2) }
    if ((Get-ResourceRuntimeMiB $Model $Metadata 128 $batch) -gt $budget) { Stop-ChatInput 'Not enough free card memory for this model. Free card memory and retry.' }
    $lo=4; $hi=[int][math]::Floor($Metadata.native_context_tokens/32)
    while ($lo -lt $hi) {
        $mid=[int][math]::Ceiling(($lo+$hi)/2.0)
        if ((Get-ResourceRuntimeMiB $Model $Metadata ($mid*32) $batch) -le $budget) { $lo=$mid } else { $hi=$mid-1 }
    }
    $context=$lo*32
    $batch=[math]::Min($batch,$context)
    return [pscustomobject]@{context_tokens=$context;batch_tokens=[int]$batch;output_tokens=0;runtime_mib=(Get-ResourceRuntimeMiB $Model $Metadata $context $batch);native_context_tokens=$Metadata.native_context_tokens;available_mib=[math]::Floor($Snapshot.available_kib/1024);mode='automatic'}
}
function Get-ContextModel($Model,$Profile,[int]$ContextTokens=2048,$Metadata=$null,[int]$Batch=1) {
    Assert-ResourceArchitecture $Model
    Assert-ModelBudget $Model $Profile
    $maximum=if ($null -ne $Metadata) { $Metadata.native_context_tokens } else { $Model.context_tokens }
    if ($ContextTokens -lt 128 -or $ContextTokens -gt $maximum) { Stop-ChatInput 'Context exceeds the verified model capacity. Reload the model.' }
    $selected=$Model.PSObject.Copy(); $selected.context_tokens=$ContextTokens
    if ($null -ne $Metadata) { $selected.estimated_peak_runtime_mib=Get-ResourceRuntimeMiB $Model $Metadata $ContextTokens $Batch }
    $selected.minimum_memory_mib=[long][math]::Max($Model.minimum_memory_mib,([math]::Ceiling($Model.file_size_bytes/1MB)+$selected.estimated_peak_runtime_mib))
    try { Assert-ModelBudget $selected $Profile } catch { Stop-ChatInput $_.Exception.Message }
    return $selected
}
function Get-PromptBudget([int]$ContextTokens,[int]$OutputTokens) {
    if ($ContextTokens -lt 128 -or $OutputTokens -lt 0 -or $OutputTokens -ge $ContextTokens-64) { Stop-ChatInput 'Prompt and reply must fit the allocated context.' }
    return ($ContextTokens-[math]::Max(1,$OutputTokens)-64)
}
