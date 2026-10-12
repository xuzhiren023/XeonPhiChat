#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw ('FAIL: '+$Message) }; Write-Output ('PASS: '+$Message) }
function Reject([scriptblock]$Action,[string]$Message) { $failed=$false; try { & $Action | Out-Null } catch { $failed=$true }; Check $failed $Message }
$null=New-Item -ItemType Directory -Path $Scratch -Force
$gaston=Get-ModelProfile $AppRoot 'lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k'
Check ($gaston.local_only -and $gaston.availability -ceq 'blocked_runtime' -and !$gaston.native_acceptance) 'real Gaston profile is local-only and has no native acceptance'
Check ($null -eq $gaston.estimated_peak_runtime_mib -and $null -eq $gaston.minimum_memory_mib -and $gaston.target_profiles.Count -eq 0) 'real Gaston profile declares no qualified runtime budget or hardware'
foreach ($hardware in @('unknown','xeon-phi-3120a','xeon-phi-7120p')) {
    $card=$null
    if ($hardware -cne 'unknown') { $card=Read-JsonFile (Join-Path $AppRoot ('config/hardware/'+$hardware+'.yaml')) }
    $item=@(Get-ModelChoices $AppRoot $card | Where-Object name -CEQ $gaston.id)[0]
    Check (!$item.enabled -and !$item.optimized -and !$item.engine_variant -and $item.hint.Contains('validated KNC MoE runtime') -and $item.label.Contains('runtime unavailable')) ('Gaston remains visibly disabled on '+$hardware)
}
Reject { Get-ModelEngineVariant $gaston } 'real Gaston cannot acquire an engine'
Reject { New-ChatPrompt $gaston @([pscustomobject]@{role='user';content='fixture'}) 'system' } 'real Gaston cannot produce an executable chat prompt'
$moe=(Get-ModelProfile $AppRoot 'lfm2.5-2.6b-matrices-q5_k').PSObject.Copy()
$moe.id='fixture-lfm2moe'; $moe.architecture='lfm2moe'; $moe.availability='blocked_runtime'
$moe.label='Fixture MoE pending runtime'; $moe.description='Fixture only: no real model identity.'
Write-JsonFile (Join-Path $AppRoot 'config/models/fixture-lfm2moe.yaml') $moe
try {
    $catalog=Get-ModelProfile $AppRoot $moe.id
    $profile=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
    $choice=@(Get-ModelChoices $AppRoot $profile | Where-Object name -CEQ $moe.id)[0]
    Check (!$choice.enabled -and !$choice.optimized -and !$choice.engine_variant -and $choice.hint.Contains('validated KNC MoE runtime')) 'MoE catalog entry is disabled with an explicit runtime reason'
    Reject { Get-ModelEngineVariant $catalog } 'MoE cannot select the historical or standard engine'
    Reject { New-ChatPrompt $catalog @([pscustomobject]@{role='user';content='fixture'}) 'system' } 'MoE cannot borrow the dense chat formatter'
    $catalog.availability='experimental_native'; $catalog.native_acceptance=$true
    Reject { Assert-ModelRuntime $catalog } 'profile metadata cannot fabricate MoE native support'
    $catalog.id='lfm2.5-2.6b-matrices-q5_k'
    Check (!(Test-Q5OptimizedModel $catalog)) 'dense model ID cannot grant a MoE performance badge'

    function Write-Metadata([string]$Path,[int]$KvCount=24,[int]$Used=4) {
        $writer=New-Object IO.BinaryWriter([IO.File]::Create($Path))
        function TextValue([string]$Value) { $b=[Text.Encoding]::UTF8.GetBytes($Value); $writer.Write([uint64]$b.Length); $writer.Write($b) }
        try {
            $writer.Write([uint32]0x46554747); $writer.Write([uint32]3); $writer.Write([uint64]0); $writer.Write([uint64]11)
            TextValue 'general.architecture'; $writer.Write([uint32]8); TextValue 'lfm2moe'
            foreach ($pair in @(@('context_length',128000),@('block_count',24),@('embedding_length',2048),@('attention.head_count',32),
                @('expert_count',32),@('expert_used_count',$Used),@('expert_feed_forward_length',1792),@('leading_dense_block_count',2),@('shortconv.l_cache',3))) {
                TextValue ('lfm2moe.'+$pair[0]); $writer.Write([uint32]4); $writer.Write([uint32]$pair[1])
            }
            TextValue 'lfm2moe.attention.head_count_kv'; $writer.Write([uint32]9); $writer.Write([uint32]4); $writer.Write([uint64]$KvCount)
            for ($i=0;$i -lt $KvCount;$i++) { $writer.Write([uint32]$(if ($i -in @(2,6,10,14,18,21)) { 8 } else { 0 })) }
        } finally { $writer.Dispose() }
    }
    $gguf=Join-Path $Scratch 'moe-metadata.gguf'; Write-Metadata $gguf
    $metadata=Read-ModelResources $gguf $moe
    Check ($metadata.native_context_tokens -eq 128000 -and $metadata.kv_bytes_per_token -eq 12288) 'MoE header charges KV to its six attention layers'
    Check ($metadata.expert_count -eq 32 -and $metadata.experts_per_token -eq 4) 'expert count and selected experts remain separate'
    Check (!$metadata.allocation_supported -and $null -eq $metadata.activation_bytes_per_token) 'no dense activation estimate is presented as qualified MoE memory'
    Reject { Get-AutoResourcePlan $moe $profile $metadata ([pscustomobject]@{available_kib=16000000}) } 'automatic allocation refuses unqualified MoE scratch/state accounting'
    Reject { Get-ContextModel $moe $profile 2048 $metadata } 'manual context selection cannot bypass MoE memory qualification'
    Reject { Get-ResourceRuntimeMiB $moe $metadata 2048 32 } 'low-level resource calculator also rejects MoE allocation'
    Reject { Get-MemoryRequirement $moe $profile -IncludeModelFile } 'legacy memory forecast cannot accept an unqualified MoE estimate'
    Write-Metadata $gguf 23
    Reject { Read-ModelResources $gguf $moe } 'truncated per-layer KV array rejected'
    Write-Metadata $gguf 24 33
    Reject { Read-ModelResources $gguf $moe } 'more active experts than total experts rejected'
    Write-Metadata $gguf 4097
    Reject { Read-ModelResources $gguf $moe } 'oversized retained metadata arrays rejected'
} finally { Remove-Item -LiteralPath (Join-Path $AppRoot 'config/models/fixture-lfm2moe.yaml') -Force }
