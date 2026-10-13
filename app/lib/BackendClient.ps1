Set-StrictMode -Version Latest
if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'ChatCore.ps1'))) {
    throw 'Application files are incomplete. Extract the complete Phi Chat installer again.'
}
# Read-only catalog/prompt policy is shared in the assembled app. SSH and card
# execution are loaded only by the separate Invoke-PhiJob worker process.
. (Join-Path $PSScriptRoot 'ChatCore.ps1')
. (Join-Path $PSScriptRoot 'JobProtocol.ps1')

function Start-PhiWorkerProcess([string]$AppRoot,[string]$JobDirectory) {
    $process=New-Object Diagnostics.Process
    $process.StartInfo.FileName=(Get-Command powershell.exe).Source
    $process.StartInfo.Arguments=Join-NativeArguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $AppRoot 'Invoke-PhiJob.ps1'),'-JobDir',$JobDirectory)
    $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.CreateNoWindow=$true
    if (!$process.Start()) { $process.Dispose(); throw 'Background worker did not start.' }
    return $process
}

function Start-PhiBackendJob([string]$AppRoot,[string]$DataDirectory,$Request) {
    Assert-PhiJobProtocol $Request
    $Request | Add-Member -NotePropertyName protocol_version -NotePropertyValue 2 -Force
    $directory=Join-Path $DataDirectory ('jobs/job-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
    $null=New-Item -ItemType Directory -Path $directory
    try {
        Write-JsonFile (Join-Path $directory 'request.json') $Request
        $process=Start-PhiWorkerProcess $AppRoot $directory
        return [pscustomobject]@{process=$process;directory=$directory}
    } catch {
        Remove-Item -LiteralPath (Join-Path $directory 'request.json') -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Stop-PhiBackendJob([string]$JobDirectory) {
    Write-Utf8 (Join-Path $JobDirectory 'cancel') 'stop'
}
