#Requires -Version 5.1
param([string]$AppRoot,[string]$Scratch)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $AppRoot 'lib/ChatCore.ps1')
. (Join-Path $AppRoot 'lib/Transport.ps1')
function Check([bool]$Value,[string]$Message) {if (!$Value) {throw ('FAIL: '+$Message)};Write-Output ('PASS: '+$Message)}
function Set-JobStatus {param($Message)}
function Set-LoadProgress {param($Stage,$Bytes,$Total,$Seconds,[switch]$Complete)}
function Update-LoadTemperature {}
function Assert-JobActive {if ($script:cancel) {throw 'Fixture cancellation'}}
$script:cancel=$false
$oldLocal=$env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA=Join-Path $Scratch 'local'
    $previous=Join-Path $env:LOCALAPPDATA 'Programs/PhiChat/1.6.1'
    $current=Join-Path $env:LOCALAPPDATA 'Programs/PhiChat/1.6.5'
    foreach ($version in @($previous,$current)) {
        $null=New-Item -ItemType Directory -Path ($version+'/app/models/uniform-q5-k'),($version+'/app/data') -Force
        Write-JsonFile ($version+'/installation.json') ([pscustomobject]@{product='PhiChat'})
    }
    $script:connection=[pscustomobject]@{project_dir=($current+'/app')}
    $script:data=$current+'/app/data'
    $model=Get-ProjectorProfile (Get-ModelProfile $AppRoot 'step3-vl-10b-q5_k_m')
    $source=Join-Path ($previous+'/app') $model.model_path
    Write-Utf8 $source 'GGUFfixture matching projector'
    $file=Get-Item -LiteralPath $source
    $model.file_size_bytes=$file.Length
    $model.sha256=(Get-PhiFileHash -LiteralPath $source).Hash.ToLowerInvariant()
    Write-JsonFile ($previous+'/app/data/model-'+$model.id+'.json') ([pscustomobject]@{path=$file.FullName;bytes=$file.Length;modified_ticks=$file.LastWriteTimeUtc.Ticks;sha256=$model.sha256})
    function Get-PhiFileHash {throw 'Unchanged prior-installation receipt must avoid another hash.'}
    function Receive-ModelDownload {throw 'An existing pinned model must not download again.'}
    $found=Get-LocalModel $model
    Check ($found -ieq (Join-Path $script:connection.project_dir $model.model_path)) 'Load automatically adopts a nested projector from the previous installation'
    Check ((Get-Item $source).Length -eq $model.file_size_bytes) 'previous installation remains usable'
    Check ((Get-LocalModel $model) -ceq $found) 'repeat Load reuses the current receipt without hashing or downloading'
    $receipt=Read-JsonFile ($script:data+'/model-'+$model.id+'.json')
    Check ($receipt.path -ceq (Get-Item $found).FullName -and $receipt.sha256 -ceq $model.sha256) 'adopted model receipt names the new installation'

    # Exercise the cross-volume fallback without requiring two physical disks.
    & {
        function New-Item {throw 'Fixture: hard links unavailable'}
        $part=Join-Path $Scratch 'copied.gguf'
        Copy-ModelFile $source $part $model.file_size_bytes
        Check ([IO.File]::ReadAllText($part) -ceq [IO.File]::ReadAllText($source)) 'ordinary copy fallback retains exact bytes'
        $script:cancel=$true
        $stopped=$false
        try {Copy-ModelFile $source ($part+'.cancel') $model.file_size_bytes} catch {$stopped=$true}
        $script:cancel=$false
        Check $stopped 'copy fallback responds to Stop'
    }
    # A new installation already gets its projector from Setup. Missing decoder
    # weights still use the existing immutable automatic download path.
    $decoder=Get-ModelProfile $AppRoot 'step3-vl-10b-q5_k_m'
    $decoder.file_size_bytes=$file.Length; $decoder.sha256=$model.sha256
    function Receive-ModelDownload {
        param($Uri,$Path,$TotalBytes)
        $script:downloadUri=$Uri.AbsoluteUri
        Copy-Item -LiteralPath $source -Destination $Path
    }
    function Get-PhiFileHash {param($LiteralPath,$Algorithm='SHA256');Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm}
    $downloaded=Get-LocalModel $decoder
    Check ((Test-Path $downloaded) -and $script:downloadUri -ceq ('https://huggingface.co/'+$decoder.repository+'/resolve/'+$decoder.revision+'/'+$decoder.filename)) 'first Step3 decoder download remains pinned and automatic'
    # Interrupted downloads never leave a complete-looking destination.
    $decoder.id='interrupted';$decoder.filename='interrupted.gguf'
    function Receive-ModelDownload {param($Uri,$Path,$TotalBytes);Write-Utf8 $Path 'partial';throw 'Fixture network interruption'}
    $failed=$false
    try {Get-LocalModel $decoder | Out-Null} catch {$failed=$true}
    Check ($failed -and !(Test-Path (Join-Path $script:connection.project_dir 'models/interrupted.gguf')) -and @(Get-ChildItem ($script:connection.project_dir+'/models') -Filter '*.part').Count -eq 0) 'failed download cleans only its temporary file and remains retryable'
} finally {$env:LOCALAPPDATA=$oldLocal}
