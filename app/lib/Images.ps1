# Session-owned images. Requests carry opaque IDs, never arbitrary filesystem paths.
function Test-ImageModel($Model) {
    return ($Model.PSObject.Properties['vision_adapter'] -and $Model.vision_adapter -ceq 'step3vl-v1')
}
function Get-MessageImages($Message) {
    if ($Message.PSObject.Properties['images']) { foreach ($image in @($Message.images)) { $image } }
}
function Assert-ImageReference($Image) {
    foreach ($field in @('id','name','bytes','sha256','width','height')) {
        if (!$Image -or !$Image.PSObject.Properties[$field]) { throw 'Incomplete image attachment.' }
    }
    if ($Image.id -cnotmatch '^[a-f0-9]{32}$' -or $Image.sha256 -cnotmatch '^[a-f0-9]{64}$' -or
        $Image.bytes -lt 1 -or $Image.bytes -gt 32MB -or $Image.width -lt 1 -or $Image.height -lt 1 -or
        $Image.width -gt 4096 -or $Image.height -gt 4096) { throw 'Invalid image attachment.' }
}
function Get-ImagePath([string]$Data,$Image) {
    Assert-ImageReference $Image
    return Join-Path $Data ('attachments/'+$Image.id+'.png')
}
function Read-ChatImage([string]$Path,[int]$PreviewWidth=0) {
    Add-Type -AssemblyName PresentationCore,WindowsBase
    $stream=[IO.File]::OpenRead($Path)
    try {
        $bitmap=New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit(); $bitmap.CacheOption='OnLoad'; $bitmap.StreamSource=$stream
        if ($PreviewWidth -gt 0) { $bitmap.DecodePixelWidth=$PreviewWidth }
        $bitmap.EndInit(); $bitmap.Freeze()
        return $bitmap
    } finally { $stream.Dispose() }
}
function Import-ChatImage([string]$Data,[string]$Path) {
    Add-Type -AssemblyName PresentationCore,WindowsBase
    $file=Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($file.PSIsContainer -or $file.Extension.ToLowerInvariant() -notin @('.png','.jpg','.jpeg','.bmp') -or $file.Length -gt 32MB) {
        throw 'Choose a PNG, JPEG or BMP image up to 32 MB.'
    }
    # Read dimensions before full decode. Preview and model use the same PNG.
    $stream=[IO.File]::OpenRead($file.FullName)
    try {
        $decoder=[Windows.Media.Imaging.BitmapDecoder]::Create($stream,[Windows.Media.Imaging.BitmapCreateOptions]::DelayCreation,[Windows.Media.Imaging.BitmapCacheOption]::None)
        $frame=$decoder.Frames[0]; $width=$frame.PixelWidth; $height=$frame.PixelHeight
        if ($width -lt 1 -or $height -lt 1 -or [long]$width*$height -gt 80000000) { throw 'This image is too large to decode. Resize it and try again.' }
    } finally { $stream.Dispose() }
    $decodeWidth=if ([math]::Max($width,$height) -gt 4096) { [int][math]::Floor($width*4096.0/[math]::Max($width,$height)) } else { 0 }
    $bitmap=Read-ChatImage $file.FullName $decodeWidth
    $id=[Guid]::NewGuid().ToString('N'); $folder=Join-Path $Data 'attachments'
    $null=New-Item -ItemType Directory -Path $folder -Force
    $target=Join-Path $folder ($id+'.png')
    try {
        $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $output=[IO.File]::Open($target,[IO.FileMode]::CreateNew)
        try { $encoder.Save($output) } finally { $output.Dispose() }
        $result=[pscustomobject]@{id=$id;name=$file.Name;bytes=(Get-Item -LiteralPath $target).Length;sha256=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant();width=$bitmap.PixelWidth;height=$bitmap.PixelHeight}
        Assert-ImageReference $result
        return $result
    } catch { Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue; throw }
}
function Assert-StoredImage([string]$Data,$Image) {
    $path=Get-ImagePath $Data $Image
    $file=Get-Item -LiteralPath $path -ErrorAction Stop
    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $file.Length -ne $Image.bytes -or
        (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $Image.sha256) { Stop-ChatInput 'An attached image is missing or changed. Remove it and attach it again.' }
    return $path
}
function Remove-UnreferencedImages([string]$Data,[object[]]$Sessions) {
    $keep=@{}
    foreach ($session in $Sessions) {
        foreach ($row in @($session.messages)+@($session.bubbles)+@($session)) {
            foreach ($im in @(Get-MessageImages $row)) { $keep[$im.id]=$true }
        }
    }
    $folder=Join-Path $Data 'attachments'
    if (!(Test-Path -LiteralPath $folder)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $folder -File -Filter '*.png') {
        if ($file.BaseName -cmatch '^[a-f0-9]{32}$' -and !$keep.ContainsKey($file.BaseName)) { Remove-Item -LiteralPath $file.FullName -Force }
    }
}
