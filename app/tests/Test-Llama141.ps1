#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/ChatCore.ps1')
function Check($Value,[string]$Message) { if (!$Value) { throw "FAIL: $Message" }; Write-Host "PASS: $Message" }
$a=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-3120a.yaml')
$p=Read-JsonFile (Join-Path $root 'config/hardware/xeon-phi-7120p.yaml')
$q2=Get-ModelProfile $root 'llama-3.3-8b-abliterated-q2_k'
$q5=Get-ModelProfile $root 'llama-3.3-8b-abliterated-q5_k_m'
Assert-ModelRuntime $q2; Assert-ModelRuntime $q5
Assert-ModelBudget $q2 $a; Assert-ModelBudget $q5 $p
$rejected=$false;try { Assert-ModelBudget $q5 $a } catch { $rejected=$true }
Check $rejected '3120A rejects Q5 weights plus runtime; no budget bypass'
Check ((Get-ThreadChoice $a $q2).generation -eq 168 -and (Get-ThreadChoice $p $q5).generation -eq 180) 'Llama reaches explicit modern SKU scheduler'
$context=Get-ContextModel $q2 $a 2048
Check ($context.context_tokens -eq 2048) '2K context retained despite 128K model label'
$rejected=$false;try { Get-ContextModel $q2 $a 4096 | Out-Null } catch { $rejected=$true };Check $rejected 'unsupported 4K rejected without invalidating model'
$dir=Join-Path ([IO.Path]::GetTempPath()) ('phi141-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $dir
try {
    $file=Join-Path $dir 'model.gguf';$receipt=Join-Path $dir 'identity.json'
    [IO.File]::WriteAllBytes($file,[Text.Encoding]::ASCII.GetBytes('GGUFfixture141'))
    $m=[pscustomobject]@{file_size_bytes=(Get-Item $file).Length;sha256=(Microsoft.PowerShell.Utility\Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant()}
    $script:hashCalls=0
    function Get-FileHash { param($LiteralPath,$Algorithm);$script:hashCalls++;Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm }
    Assert-ModelFile $file $m $receipt
    1..5 | ForEach-Object { Assert-ModelFile $file $m $receipt }
    Check ($script:hashCalls -eq 1) 'first admission hashes once; repeated preparation reuses receipt'
    [IO.File]::SetLastWriteTimeUtc($file,[DateTime]::UtcNow.AddMinutes(1))
    Assert-ModelFile $file $m $receipt
    Check ($script:hashCalls -eq 2) 'changed model timestamp invalidates receipt'
    [IO.File]::WriteAllText($receipt,'invalid receipt')
    Assert-ModelFile $file $m $receipt
    Check ($script:hashCalls -eq 3) 'invalid receipt is reverified before use'
    $m.sha256=('0'*64);$rejected=$false
    try { Assert-ModelFile $file $m $receipt } catch { $rejected=$true }
    Check ($rejected -and $script:hashCalls -eq 4) 'changed pin rehashes and rejects incorrect digest'
} finally { Remove-Item $dir -Recurse -Force }
