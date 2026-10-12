Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/ChatCore.ps1')
function Check([bool]$Value,[string]$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Output "PASS: $Message" }
$a=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-3120a.yaml')
$p=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-7120p.yaml')
$m=Get-ModelProfile $root 'lfm2.5-2.6b-q5_k_m'
$messages=@([pscustomobject]@{role='user';content='Explain RAM.'})
$one=Get-ChatForecast $m $a 2048 128 $messages 'System'
Check (!$one.memory_risk -and $one.context_fit_proven) '3120A short LFM Q5 2K forecast fits its profile'
Check ($one.total_model_runtime_mib -eq [math]::Ceiling($m.file_size_bytes/1MB)+1536) 'shared weights and runtime counted once'
$longReply=Get-ChatForecast $m $a 2048 512 $messages 'System'
Check ($longReply.runtime_full_context_mib -eq $one.runtime_full_context_mib -and $longReply.prompt_budget -lt $one.prompt_budget) 'reply length changes token space, not preallocated full-context memory'
$large=Get-ChatForecast $m $a 4096 128 $messages 'System'
Check $large.memory_risk 'forecast refuses extended context without verified GGUF metadata'
$low=Get-ChatForecast $m $a 2048 128 $messages 'System' ([pscustomobject]@{available_kib=1700*1024})
Check ($low.memory_risk -and $low.estimated_headroom_mib -eq -92) 'live estimate includes 256 MiB reserve and reports a shortage'
$many=@([pscustomobject]@{role='user';content=('你好世界'*700)})
$wide=Get-ChatForecast $m $a 2048 128 $many 'System'
Check ($wide.needs_native_count -and !$wide.context_fit_proven) 'multibyte estimate never claims a fit without a bound or native count'
$rate=New-Object PhiChat.TextRate
Check ($null -eq $rate.Add('',0)) 'no invented token speed before output'
$null=$rate.Add('abcd',1)
$measured=$rate.Add('efghijkl',3)
Check ($measured -eq 1) 'live estimate counts characters over time, not byte chunks'
$unicode=New-Object PhiChat.TextRate
$null=$unicode.Add(([char]::ConvertFromUtf32(128512)),0)
Check ($unicode.EstimatedTokens -eq 0.25) 'surrogate pair counts as one displayed Unicode character'
$null=$rate.Add('',20)
Check ($rate.Add('',22) -eq 0) 'stalled output decays to zero in rolling window'
Write-Output 'PASS: hardware-free forecasting and live-rate checks'
