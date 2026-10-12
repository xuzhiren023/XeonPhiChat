#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$null=New-Item -ItemType Directory -Path $Scratch -Force
$model=Get-ModelProfile $AppRoot 'lfm2.5-2.6b-q5_k_m'
$small=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-3120a.yaml')
$large=Read-JsonFile (Join-Path $AppRoot 'config/hardware/xeon-phi-7120p.yaml')
# Minimal metadata-only GGUF fixture, including a skipped tokenizer array.
$file=Join-Path $Scratch 'metadata.gguf'
$writer=New-Object IO.BinaryWriter([IO.File]::Create($file))
function StringValue([string]$Text) { $bytes=[Text.Encoding]::UTF8.GetBytes($Text); $writer.Write([uint64]$bytes.Length); $writer.Write($bytes) }
try {
    $writer.Write([uint32]0x46554747); $writer.Write([uint32]3); $writer.Write([uint64]0); $writer.Write([uint64]7)
    StringValue 'general.architecture'; $writer.Write([uint32]8); StringValue 'lfm2'
    foreach ($pair in @(@('context_length',32768),@('block_count',30),@('embedding_length',2048),@('attention.head_count',32),@('attention.head_count_kv',8))) {
        StringValue ('lfm2.'+$pair[0]); $writer.Write([uint32]4); $writer.Write([uint32]$pair[1])
    }
    StringValue 'tokenizer.ggml.tokens'; $writer.Write([uint32]9); $writer.Write([uint32]8); $writer.Write([uint64]2); StringValue 'one'; StringValue 'two'
} finally { $writer.Dispose() }
$metadata=Read-ModelResources $file $model
Check ($metadata.native_context_tokens -eq 32768 -and $metadata.kv_bytes_per_token -eq 61440) 'reads actual model context and F16 cache geometry without tensor scans'
$a=Get-AutoResourcePlan $model $small $metadata ([pscustomobject]@{available_kib=3500*1024})
$p=Get-AutoResourcePlan $model $large $metadata ([pscustomobject]@{available_kib=12000*1024})
Check ($a.context_tokens -gt 2048 -and $p.context_tokens -gt $a.context_tokens -and $p.context_tokens -le 32768) 'context scales with card RAM and never exceeds the model capacity'
$tight=Get-AutoResourcePlan $model $small $metadata ([pscustomobject]@{available_kib=1900*1024})
Check ($tight.context_tokens -lt $a.context_tokens -or $tight.batch_tokens -lt $a.batch_tokens) 'fresh low-memory telemetry reduces allocation'
$selected=Get-ContextModel $model $large $p.context_tokens $metadata $p.batch_tokens
Check ($selected.context_tokens -eq $p.context_tokens -and $model.context_tokens -eq 2048) 'allocation does not mutate the pinned baseline profile'
$failed=$false; try { Get-AutoResourcePlan $model $small $metadata ([pscustomobject]@{available_kib=512*1024}) } catch { $failed=$_.Exception.Data['PhiChatInput'] -eq $true }
Check $failed 'insufficient memory is recoverable before native launch'
Check ((Get-PromptBudget 16384 8192) -eq 8128) 'no 512-token application output ceiling'
$null=New-ChatPrompt $model @([pscustomobject]@{role='user';content='Hello'}) 'System' 8192
Check $true 'prompt formatter accepts model-sized output allocations'

# Exercise the real prompt allocator with deterministic native count receipts.
. (Join-Path $AppRoot 'lib/Transport.ps1')
$script:root=$AppRoot; $script:job=$Scratch; $script:data=$Scratch
$script:health=[pscustomobject]@{profile=$large;serial='CARD'}
$script:request=[pscustomobject]@{model='lfm2.5-2.6b-q5_k_m';batch=$p.batch_tokens;output_tokens=0}
$script:sessionMetadata=$null; $script:counts=New-Object Collections.ArrayList
function Invoke-Generation { param($Model,$State,$RemoteModel,$Prompt,$Threads,$Tokens,$Directory,[switch]$CheckOnly)
    if (!$CheckOnly -or $Tokens -ne 0) { throw 'Automatic output must use a count-only probe.' }
    $null=$script:counts.Add($Prompt)
    return [pscustomobject]@{prompt_tokens=777;prompt_rejected=$false;memory_samples=1}
}
$prompt=Get-CheckedChatPrompt $selected ([pscustomobject]@{}) '/fixture' (Get-ThreadChoice $large $model) @([pscustomobject]@{role='user';content='Hello'}) 'System' 0
Check ($script:request.output_tokens -eq $selected.context_tokens-777-64 -and $script:request.output_tokens -gt 512) 'reply receives all remaining context from the exact native token count'
$record=Read-JsonFile (Join-Path $Scratch 'prompt-budget.json')
Check ($record.native_counted -and $record.reserved_reply_tokens -eq $script:request.output_tokens) 'allocation receipt records the actual remaining output budget'

$script:request=[pscustomobject]@{action='Chat';owner_pid=0}
$script:operatorCancelled=$false; $script:cleanupMode=$false; $script:cleanupConfirmed=$false
$script:cardLockOwned=$true; $script:cardLockToken='fixture-owner'
Write-Utf8 (Join-Path $Scratch 'cancel') 'stop'
$stopped=$false; try { Assert-JobActive } catch { $stopped=$true }
Check ($stopped -and $script:operatorCancelled -and $null -eq (Get-ChatCancellationStatus)) 'Stop is detected but cannot restore readiness while the card lease is held'
function Invoke-Card([string]$Command) { if ($Command.StartsWith('if test ! -d')) { return 'clean' }; return '' }
Release-CardWorkloadLock
$cancelled=Get-ChatCancellationStatus
Check ($cancelled.state -ceq 'cancelled' -and $cancelled.preserve_ready) 'confirmed native cleanup publishes a resumable cancellation'
$script:cardLockOwned=$true; $script:cleanupConfirmed=$false
function Invoke-Card([string]$Command) { return '' }
$failed=$false; try { Release-CardWorkloadLock } catch { $failed=$true }
Check ($failed -and $null -eq (Get-ChatCancellationStatus)) 'unconfirmed cleanup cannot masquerade as a safe Stop'
$script:operatorCancelled=$false; $script:cardLockOwned=$false; $script:cleanupConfirmed=$true
Check ($null -eq (Get-ChatCancellationStatus)) 'a native or thermal failure is never labelled user cancellation'

$choices=@(Get-ModelChoices $AppRoot $large)
Check ($choices.Count -eq 8 -and @($choices | Where-Object name -Match '^(tinyllama|dolphin-phi2)').Count -eq 0) 'retired models are absent from the application catalog'
