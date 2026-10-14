#Requires -Version 5.1
[CmdletBinding()]
param([string]$AssetsDirectory='', [string]$ModelDirectory='', [string[]]$ModelIds=@(),
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,95}$')][string]$ModelPackName='LocalModels',
    [switch]$SourceOnly, [switch]$ModelsOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'setup/lib/SetupCore.ps1')
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$version=Get-PhiVersion $root
$dist=Join-Path $root 'dist'; New-Directory $dist
if ($SourceOnly -and $ModelsOnly) { throw 'Choose source-only or models-only packaging, not both.' }
if ($ModelsOnly -and !$ModelDirectory) { throw '-ModelsOnly requires -ModelDirectory.' }

function New-PhiZip([string]$Name,$Entries) {
    $target=Join-Path $dist $Name
    if (Test-Path -LiteralPath $target) { throw ('Release output exists; preserve it or choose a new version: '+$target) }
    $part=$target+'.part'; $zip=$null; $stream=$null
    try {
        $stream=[IO.File]::Open($part,[IO.FileMode]::CreateNew)
        $zip=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
        $names=@{}
        foreach ($item in $Entries) {
            if ($names.ContainsKey($item.name)) { throw ('Duplicate archive member: '+$item.name) }
            $names[$item.name]=$true
            Assert-RegularPath $item.path
            $level=if ($item.name -match '\.(gguf|tar)$') { [IO.Compression.CompressionLevel]::NoCompression } else { [IO.Compression.CompressionLevel]::Optimal }
            $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$item.path,$item.name,$level)
        }
        $zip.Dispose(); $zip=$null; $stream.Dispose(); $stream=$null
        # Verify each member against its input, including large model assets.
        $read=[IO.Compression.ZipFile]::OpenRead($part)
        try {
            if ($read.Entries.Count -ne $names.Count) { throw 'ZIP member count mismatch.' }
            foreach ($item in $Entries) {
                $entry=$read.GetEntry($item.name)
                if (!$entry -or $entry.Length -ne (Get-Item -LiteralPath $item.path).Length) { throw ('ZIP member size mismatch: '+$item.name) }
                $input=$entry.Open(); $sha=[Security.Cryptography.SHA256]::Create()
                try { $hash=[BitConverter]::ToString($sha.ComputeHash($input)).Replace('-','').ToLowerInvariant() } finally { $input.Dispose(); $sha.Dispose() }
                if ($hash -cne (Get-FileHash -LiteralPath $item.path).Hash.ToLowerInvariant()) { throw ('ZIP member SHA-256 mismatch: '+$item.name) }
            }
        } finally { $read.Dispose() }
        [IO.File]::Move($part,$target)
        $sum=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()
        Write-Utf8 ($target+'.sha256') ($sum+'  '+$Name+"`n")
        Write-Output ('VERIFIED: '+$target)
    } finally {
        if ($zip) { $zip.Dispose() }; if ($stream) { $stream.Dispose() }
        if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part }
    }
}
$sources=@()
$allowed=@('app','setup','tests','tools','docs','licenses','.github')
foreach ($name in $allowed) {
    foreach ($file in @(Get-TreeFiles (Join-Path $root $name) @('__pycache__','*/__pycache__','*.pyc'))) {
        $relative=Get-Relative $file.FullName $root
        if ($relative -match '(^|/)(private|data|dependencies|\.git)(/|$)|/connection\.yaml$|\.(gguf|exe|dll|tar|zip|pem|key)$') { throw ('Machine state/binary found in source tree: '+$relative) }
        $sources+=@([pscustomobject]@{path=$file.FullName;name=('PhiChat-'+$version+'/'+$relative)})
    }
}
foreach ($name in @('VERSION','README.md','AGENTS.md','LICENSES.md','MIGRATION.json','.gitignore','.gitattributes','Setup.cmd','Setup.ps1','Start.cmd','Start.ps1','Add-Models.cmd','assets/runtime-manifest.json','assets/optimized-models.json','assets/upstream-runtime-build.json','assets/multimodal-runtime-build.json','assets/priming-runtime-build.json')) {
    $path=Join-Safe $root $name
    if (!(Test-Path -LiteralPath $path)) { throw ('Required source file missing: '+$name) }
    $sources+=@([pscustomobject]@{path=$path;name=('PhiChat-'+$version+'/'+$name)})
}
foreach ($file in @(Get-TreeFiles (Join-Path $root 'assets/model-provenance'))) {
    if ($file.Extension -cne '.json') { throw 'Only JSON provenance is allowed in the model-provenance directory.' }
    $sources+=@([pscustomobject]@{path=$file.FullName;name=('PhiChat-'+$version+'/'+(Get-Relative $file.FullName $root))})
}
if ($SourceOnly) { New-PhiZip ('PhiChat-'+$version+'-Source.zip') $sources; exit }
if (!$ModelsOnly) {
if (!$AssetsDirectory) { $AssetsDirectory=Join-Path $root 'assets/payloads' }
$manifest=Get-PhiAssets $root $AssetsDirectory
# Developer suites/build helpers belong in the source ZIP, not the installer.
$entries=@($sources | Where-Object { $_.name -notmatch '/(?:tests|tools|\.github)/|/app/Test-[^/]+\.ps1$|/(?:AGENTS\.md|MIGRATION\.json|\.gitignore|\.gitattributes)$' })
foreach ($asset in $manifest.assets) { $entries+=@([pscustomobject]@{path=(Join-Safe $AssetsDirectory $asset.file);name=('PhiChat-'+$version+'/assets/payloads/'+$asset.file)}) }
New-PhiZip ('PhiChat-'+$version+'-Windows.zip') $entries
}
if ($ModelDirectory) {
    $models=@(Get-PhiModelPackSelection $root $ModelDirectory $ModelIds)
    $entries=@([pscustomobject]@{path=(Join-Path $root 'assets/optimized-models.json');name='optimized-models.json'},
        [pscustomobject]@{path=(Join-Path $root 'docs/MODEL-PACK.md');name='README.md'},
        [pscustomobject]@{path=(Join-Path $root 'docs/MODELS.md');name='docs/MODELS.md'},
        [pscustomobject]@{path=(Join-Path $root 'docs/LFM2-MOE.md');name='docs/LFM2-MOE.md'},
        [pscustomobject]@{path=(Join-Path $root 'docs/IMAGES.md');name='docs/IMAGES.md'})
    foreach ($model in $models) {
        $path=Join-Safe $ModelDirectory $model.path
        Assert-PhiAsset $path ([pscustomobject]@{file=$model.path;bytes=$model.bytes;sha256=$model.sha256})
        $entries+=@([pscustomobject]@{path=$path;name=$model.path})
        foreach ($field in @('provenance_file','audit_file')) {
            if ($model.PSObject.Properties[$field]) {
                $relative=[string]$model.$field
                if ($relative -notmatch '^assets/model-provenance/[a-z0-9_.-]+\.json$') { throw 'Invalid model evidence path.' }
                $entries+=@([pscustomobject]@{path=(Join-Safe $root $relative);name=$relative})
            }
        }
    }
    New-PhiZip ('PhiChat-'+$version+'-'+$ModelPackName+'.zip') $entries
}

