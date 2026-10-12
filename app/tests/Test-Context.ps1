Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/ChatCore.ps1')
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$model=Get-ModelProfile $root 'lfm2.5-2.6b-q5_k_m'
$profile=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-7120p.yaml')
$metadata=[pscustomobject]@{native_context_tokens=32768;kv_bytes_per_token=61440;activation_bytes_per_token=983040;attention_heads=32}
$selected=Get-ContextModel $model $profile 8192 $metadata 32
Check ($selected.context_tokens -eq 8192 -and $model.context_tokens -eq 2048) 'verified metadata enables dynamic context without editing the model identity'
$failed=$false; try { Get-ContextModel $model $profile 65536 $metadata 32 } catch { $failed=$_.Exception.Data['PhiChatInput'] -eq $true }
Check $failed 'model capacity is enforced as a recoverable input error'
Check ((Get-PromptBudget 8192 4096) -eq 4032) 'output and input share model context'
Check (Test-RecoverableChatFailure ([pscustomobject]@{preserve_ready=$true})) 'input failures preserve loaded weights'
Check (!(Test-RecoverableChatFailure ([pscustomobject]@{preserve_ready=$false}))) 'hardware failures still invalidate readiness'
