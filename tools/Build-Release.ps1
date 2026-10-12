#Requires -Version 5.1
[CmdletBinding()]
param([string]$AssetsDirectory='', [string]$ModelDirectory='', [switch]$SourceOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'setup/lib/SetupCore.ps1')
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$version=Get-PhiVersion $root
$dist=Join-Path $root 'dist'; New-Directory $dist

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
foreach ($name in @('VERSION','README.md','AGENTS.md','LICENSES.md','MIGRATION.json','.gitignore','.gitattributes','Setup.cmd','Setup.ps1','Start.cmd','Start.ps1','Add-Models.cmd','assets/runtime-manifest.json','assets/optimized-models.json')) {
    $path=Join-Safe $root $name
    if (!(Test-Path -LiteralPath $path)) { throw ('Required source file missing: '+$name) }
    $sources+=@([pscustomobject]@{path=$path;name=('PhiChat-'+$version+'/'+$name)})
}
if ($SourceOnly) { New-PhiZip ('PhiChat-'+$version+'-Source.zip') $sources; exit }
if (!$AssetsDirectory) { $AssetsDirectory=Join-Path $root 'assets/payloads' }
$manifest=Get-PhiAssets $root $AssetsDirectory
$entries=$sources
foreach ($asset in $manifest.assets) { $entries+=@([pscustomobject]@{path=(Join-Safe $AssetsDirectory $asset.file);name=('PhiChat-'+$version+'/assets/payloads/'+$asset.file)}) }
New-PhiZip ('PhiChat-'+$version+'-Windows.zip') $entries
if ($ModelDirectory) {
    $models=Read-Json (Join-Path $root 'assets/optimized-models.json')
    $entries=@([pscustomobject]@{path=(Join-Path $root 'assets/optimized-models.json');name='optimized-models.json'},[pscustomobject]@{path=(Join-Path $root 'docs/MODELS.md');name='README.md'})
    foreach ($model in $models.models) {
        $path=Join-Safe $ModelDirectory $model.path
        Assert-PhiAsset $path ([pscustomobject]@{file=$model.path;bytes=$model.bytes;sha256=$model.sha256})
        $entries+=@([pscustomobject]@{path=$path;name=$model.path})
    }
    New-PhiZip ('PhiChat-'+$version+'-OptimizedModels.zip') $entries
}

