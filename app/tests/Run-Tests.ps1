#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$bad=$false
Get-ChildItem -LiteralPath $root -Filter '*.ps1' -Recurse | ForEach-Object {
    $tokens=$null; $errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { $errors | Write-Output; $bad=$true }
}
if ($bad) { throw 'PowerShell syntax checks failed.' }
foreach ($name in @('Test-Llama141.ps1','Test-Preparation.ps1','Test-Forecast.ps1','Test-Context.ps1','Test-Chat.ps1','Test-Memory.ps1','Test-Hardware.ps1','Test-Import.ps1','Test-StateFiles.ps1','Test-Transport.ps1')) {
    # Isolate each suite's imported functions/C# state and exit behavior.
    $engine=Join-Path $PSHOME $(if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'powershell.exe' } else { 'pwsh' })
    & $engine -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $name)
    if ($LASTEXITCODE -ne 0) { throw "Test suite failed: $name" }
}
Write-Output 'PASS: hardware-free PowerShell suite'
