#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$engine=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
$scratch=Join-Path ([IO.Path]::GetTempPath()) ('phichat-tests-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $scratch
function Run-Test([string]$File,[string[]]$Arguments=@()) {
    & $engine -NoProfile -STA -ExecutionPolicy Bypass -File $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('Test failed: '+$File) }
}
try {
    $files=@(Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '[\\/](dist|data|\.git)[\\/]' })
    foreach ($file in $files) {
        $tokens=$null; $errors=$null
        [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
        if ($errors.Count) { throw ('Syntax errors in '+$file.FullName+': '+($errors.Message -join '; ')) }
    }
    Write-Output ('PASS: '+$files.Count+' PowerShell scripts parsed')
    Run-Test (Join-Path $root 'tests/Test-ModelManifest.ps1')
    Run-Test (Join-Path $root 'setup/tests/Test-SshPersistence.ps1')
    Run-Test (Join-Path $root 'setup/tests/Test-Setup.ps1')
    Run-Test (Join-Path $root 'setup/tests/Test-SetupEntry.ps1')
    Run-Test (Join-Path $root 'setup/tests/Test-SetupUpdate.ps1')
    Run-Test (Join-Path $root 'setup/tests/Test-Services.ps1')
    Run-Test (Join-Path $root 'setup/tests/Test-FirstRun.ps1')
    Run-Test (Join-Path $root 'app/tests/Run-Tests.ps1')
    foreach ($name in @('Test-RuntimeGuard','Test-ModernTransaction','Test-GccRuntime')) {
        Run-Test (Join-Path $root ('app/tests/'+$name+'.ps1')) @('-Scratch',(Join-Path $scratch $name))
    }
    $app=Join-Path $scratch 'app with spaces'
    Copy-Item -LiteralPath (Join-Path $root 'app') -Destination $app -Recurse
    foreach ($name in @('Test-ChatControls','Test-ChatExperience','Test-ModelRuntimePairing','Test-AutoResources','Test-MoeCompatibility','Test-VisionModels','Test-ModelFiles','Test-Images','Test-Priming','Test-Performance')) {
        Run-Test (Join-Path $root ('tests/'+$name+'.ps1')) @('-AppRoot',$app,'-Scratch',(Join-Path $scratch $name))
    }
    Run-Test (Join-Path $root 'tests/Test-StandaloneRuntimePins.ps1') @('-AppRoot',$app)
    Write-Output 'PASS: standalone host suite. No card, MPSS, network settings or existing identities modified.'
} finally {
    $resolved=[IO.Path]::GetFullPath($scratch)
    if (!$resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -or (Split-Path $resolved -Leaf) -notmatch '^phichat-tests-[a-f0-9]{32}$') { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
