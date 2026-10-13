#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw ('FAIL: '+$Message) }; Write-Output ('PASS: '+$Message) }
function Reject([scriptblock]$Action,[string]$Message) { $failed=$false; try { & $Action | Out-Null } catch { $failed=$true }; Check $failed $Message }
$null=New-Item -ItemType Directory -Path $Scratch -Force
$gaston=Get-ModelProfile $AppRoot 'lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k'
Check ($gaston.local_only -and $gaston.availability -ceq 'experimental_native' -and !$gaston.native_acceptance) 'Gaston execution enabled without fabricated native acceptance'
$profile=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
$item=@(Get-ModelChoices $AppRoot $profile | Where-Object name -CEQ $gaston.id)[0]
Check ($item.enabled -and $item.engine_variant -ceq 'shared') '7120P selects the multimodal shared engine'
Reject { Assert-ModelRuntimeFeatures $gaston ([pscustomobject]@{modern_features=@('shared-multi-quant-v1')}) } 'old dense runtime cannot run MoE'
$moe=$gaston.PSObject.Copy()
try {
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
    Check ($metadata.kv_bytes_per_token -eq 12288) 'KV allocated only to attention layers'
    Check ($metadata.allocation_supported -and $metadata.activation_bytes_per_token -gt 16*2048*24 -and $metadata.recurrent_state_mib -gt 0) 'routing, expert intermediates and recurrent state counted'
    $plan=Get-AutoResourcePlan $moe $profile $metadata ([pscustomobject]@{available_kib=16000000})
    Check ($plan.context_tokens -ge 128 -and $plan.context_tokens -le 128000) 'context follows memory and native capacity'
    $need=Get-MemoryRequirement $moe $profile -IncludeModelFile
    Check ($need.model_file_mib -eq [math]::Ceiling($moe.file_size_bytes/1MB)) 'all expert weights counted'
    Write-Metadata $gguf 23
    Reject {Read-ModelResources $gguf $moe} 'invalid per-layer heads rejected'
    Write-Metadata $gguf 24 33
    Reject {Read-ModelResources $gguf $moe} 'invalid expert count rejected'
} finally {}
