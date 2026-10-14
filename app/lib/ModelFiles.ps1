function Get-PreviousModelSources($Model) {
    # Only known Phi Chat installation folders, never a drive-wide model search.
    $roots=@((Join-Path $env:LOCALAPPDATA 'Programs/PhiChat'))
    $install=Split-Path $script:connection.project_dir -Parent
    if (Test-Path -LiteralPath (Join-Path $install 'installation.json') -PathType Leaf) {
        $roots+=Split-Path $install -Parent
    }
    $seen=@{}
    foreach ($root in @($roots | Select-Object -Unique)) {
        if (!(Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($version in @(Get-ChildItem -LiteralPath $root -Directory | Where-Object Name -Match '^\d+\.\d+\.\d+(?:\.\d+)?$' | Sort-Object { [version]$_.Name } -Descending)) {
            $app=Join-Path $version.FullName 'app'
            if ($app -ieq $script:connection.project_dir) {continue}
            $receipt=Join-Path $version.FullName 'installation.json'
            if (!(Test-Path -LiteralPath $receipt -PathType Leaf)) {continue}
            try {if ((Read-JsonFile $receipt).product -cne 'PhiChat') {continue}} catch {continue}
            $paths=@(('models/'+$Model.filename),('models/uniform-q5-k/'+$Model.filename))
            foreach ($relative in $paths) {
                $path=Join-Path $app $relative
                if (!$seen.ContainsKey($path) -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                    $seen[$path]=$true
                    [pscustomobject]@{path=$path;receipt=(Join-Path $app ('data/model-'+$Model.id+'.json'))}
                }
            }
        }
    }
}
function Copy-ModelFile([string]$Source,[string]$Part,[long]$Bytes) {
    # Same-volume reuse consumes no extra model space; a normal copy also works
    # across disks. A unique temporary name is published only after completion.
    try { $null=New-Item -ItemType HardLink -Path $Part -Value $Source -ErrorAction Stop; return }
    catch { if (Test-Path -LiteralPath $Part) { throw } }
    $inputFile=$null; $outputFile=$null; $watch=[Diagnostics.Stopwatch]::StartNew()
    try {
        $inputFile=[IO.File]::OpenRead($Source)
        $outputFile=[IO.File]::Open($Part,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        $buffer=New-Object byte[] (8MB); $copied=0L; $next=0.0
        while (($count=$inputFile.Read($buffer,0,$buffer.Length)) -gt 0) {
            Assert-JobActive
            $outputFile.Write($buffer,0,$count); $copied+=$count
            if ($watch.Elapsed.TotalSeconds -ge $next) {
                Update-LoadTemperature
                Set-LoadProgress 'Reusing existing model' $copied $Bytes $watch.Elapsed.TotalSeconds
                $next=$watch.Elapsed.TotalSeconds+1
            }
        }
        if ($copied -ne $Bytes) {throw 'Existing model changed while copying. Retry Load model.'}
    } finally {
        if ($outputFile) {$outputFile.Dispose()}
        if ($inputFile) {$inputFile.Dispose()}
    }
}
function Restore-PreviousModel($Model,[string]$Destination) {
    $receiptPath=Join-Path $script:data ('model-'+$Model.id+'.json')
    foreach ($candidate in @(Get-PreviousModelSources $Model)) {
        Assert-JobActive
        $source=Get-Item -LiteralPath $candidate.path
        if ($source.Length -ne $Model.file_size_bytes) {continue}
        Set-JobStatus ('Reusing '+$Model.label+' from an earlier Phi Chat installation.')
        # A prior receipt remains valid only for the same file metadata and pin.
        # Assert-ModelFile makes the final decision; a missing/stale receipt
        # results in one admission check, never a card-side checksum scan.
        if (Test-Path -LiteralPath $candidate.receipt -PathType Leaf) {
            try {Write-JsonFile $receiptPath (Read-JsonFile $candidate.receipt)} catch {}
        }
        try { Assert-ModelFile $source.FullName $Model $receiptPath }
        catch { Assert-JobActive; continue }
        Assert-JobActive
        $null=New-Item -ItemType Directory -Path (Split-Path $Destination -Parent) -Force
        $part=$Destination+'.'+[Guid]::NewGuid().ToString('N')+'.part'
        try {
            Copy-ModelFile $source.FullName $part $source.Length
            Assert-JobActive
            $after=Get-Item -LiteralPath $source.FullName
            $copied=Get-Item -LiteralPath $part
            if ($after.Length -ne $source.Length -or $after.LastWriteTimeUtc.Ticks -ne $source.LastWriteTimeUtc.Ticks -or $copied.Length -ne $source.Length) {throw 'Existing model changed while reusing it. Retry Load model.'}
            try { [IO.File]::Move($part,$Destination) }
            catch [IO.IOException] {
                # Another window won the race; its file is checked by the caller.
                if (Test-Path -LiteralPath $Destination -PathType Leaf) {return $Destination}
                throw
            }
            $file=Get-Item -LiteralPath $Destination
            Write-JsonFile $receiptPath ([pscustomobject]@{path=$file.FullName;bytes=$file.Length;modified_ticks=$file.LastWriteTimeUtc.Ticks;sha256=$Model.sha256})
            return $file.FullName
        } finally {if (Test-Path -LiteralPath $part) {Remove-Item -LiteralPath $part -Force}}
    }
    return ''
}
