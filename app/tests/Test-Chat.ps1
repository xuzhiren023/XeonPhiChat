# Hardware-free catalog, prompts and timing regression tests.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/ChatCore.ps1')
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
function Reject([scriptblock]$Block,[string]$Message) { $failed=$false; try { $null=& $Block } catch { $failed=$true }; Check $failed $Message }
$td=Get-ModelProfile $root 'tinydolphin-q5_k_m'
$lfm=Get-ModelProfile $root 'lfm2.5-2.6b-q5_k_m'
$q2=Get-ModelProfile $root 'llama-3.3-8b-abliterated-q2_k'
$q5=Get-ModelProfile $root 'llama-3.3-8b-abliterated-q5_k_m'
$a=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-3120a.yaml')
$p=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-7120p.yaml')
Check ((Get-ThreadChoice $a).generation -eq 224 -and (Get-ThreadChoice $p).prompt -eq 240) 'full legacy SKU worker settings'
foreach ($model in @($td,$lfm,$q2)) { Assert-ModelBudget $model $a }
Reject { Assert-ModelBudget $q5 $a } '3120A rejects oversized weights'
Assert-ModelBudget $q5 $p
Check (@(Get-ModelChoices $root $a | Where-Object enabled).Count -eq 3) '3120A has three supported model choices'
Check (@(Get-ModelChoices $root $p | Where-Object enabled).Count -eq 9) '7120P admits text, MoE, Step3 and LFM2-VL profiles'
$copy=$td.PSObject.Copy(); $copy.memory_mode='copy'
Reject { Assert-ModelBudget $copy $a } 'copy-mode accounting is rejected'
$prompt=New-ChatPrompt $td @([pscustomobject]@{role='user';content='Hello'}) 'Be helpful' 1024
Check ($prompt.text -match '<\|im_start\|>user\nHello<\|im_end\|>') 'retained ChatML template accepts larger replies'
$messages=@([pscustomobject]@{role='user';content=('a'*1000)},[pscustomobject]@{role='assistant';content=('b'*1000)},[pscustomobject]@{role='user';content='Last question'})
Check ((New-ChatPrompt $td $messages 'Help' 0).omitted_pairs -eq 0) 'history retained until exact token count requires trimming'
Check ((New-ChatPrompt $td $messages 'Help' 0 -LatestOnly).omitted_pairs -eq 1) 'only whole turns omitted from native input'
Reject { New-ChatPrompt $td @([pscustomobject]@{role='user';content=('x'*262145)}) 'Help' } 'input byte safety bound remains'
Reject { New-ChatPrompt $td @([pscustomobject]@{role='assistant';content='Hi'}) 'Help' } 'message order enforced'
Reject { Get-ModelProfile $root '../invalid' } 'model path traversal rejected'
Reject { Assert-RemoteBase '/root/runtime;reboot' } 'unsafe runtime path rejected'
$step=Get-ModelProfile $root 'step3-vl-10b-q5_k_m'
Assert-ModelRuntime $step
Reject { Assert-ModelRuntimeFeatures $step ([pscustomobject]@{modern_features=@('shared-multi-quant-v1')}) } 'vision requires multimodal runtime'
Check ((Get-ThreadChoice $a $lfm).generation -eq 168 -and (Get-ThreadChoice $p $lfm).generation -eq 180) 'modern SKU worker settings preserved'
$prompt=New-ChatPrompt $lfm @([pscustomobject]@{role='user';content='Hi'}) ''
Check ($prompt.text -ceq "<|startoftext|><|im_start|>user`nHi<|im_end|>`n<|im_start|>assistant`n<think>") 'LFM exact generation template preserved'
$prompt=New-ChatPrompt $lfm @([pscustomobject]@{role='user';content='Hi'},[pscustomobject]@{role='assistant';content='<think>reasoning</think> Answer '},[pscustomobject]@{role='user';content='Again'}) 'Help'
Check (!$prompt.text.Contains('reasoning') -and $prompt.text.Contains("assistant`nAnswer<|im_end|>")) 'previous thinking omitted according to the model template'
$text="llama_print_timings: load time = 1234.56 ms`nllama_print_timings: prompt eval time = 543.00 ms / 22 tokens (24.68 ms per token, 40.52 tokens per second)`nllama_print_timings: eval time = 900.00 ms / 63 runs (14.29 ms per token, 70.00 tokens per second)"
$timing=Read-LlamaTiming $text
Check ($timing.prompt_tps -eq 40.52 -and $timing.generation_tps -eq 70 -and $timing.generation_tokens -eq 63) 'prompt/generation timing preserved'
