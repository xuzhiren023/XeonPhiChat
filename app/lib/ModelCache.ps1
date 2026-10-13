# Called only by Load, under the card-wide lease. Send never evicts or copies.
function Read-CardCacheInventory([string]$Tool) {
    $raw=Invoke-Card "bash '$Tool' inventory '$($script:cfg.source_commit)' '$($script:cardLockToken)'"
    foreach ($line in ($raw -split '\r?\n')) {
        if (!$line.Trim()) { continue }
        $m=[regex]::Match($line,'^(/root/knc-phase3-run-[A-Za-z0-9-]+/(?:model\.gguf|models/[A-Za-z0-9_.-]+\.gguf(?:\.part)?))\t([0-9]+)\t(-|[a-f0-9]{64})$')
        if (!$m.Success) { throw 'Invalid card model-cache inventory; no deletion attempted for this row.' }
        [pscustomobject]@{path=$m.Groups[1].Value;bytes=[long]$m.Groups[2].Value;identity=$m.Groups[3].Value}
    }
}
function Get-CacheModel($Entry,[object[]]$Models,$State) {
    $matches=@($Models | Where-Object { $Entry.path.EndsWith('/models/'+$_.id+'.gguf') -or $Entry.path.EndsWith('/models/'+$_.id+'.gguf.part') })
    if (!$matches.Count -and $Entry.path.EndsWith('/model.gguf')) {
        if ($Entry.path -ceq ($State.remote_base+'/model.gguf') -and $State.PSObject.Properties['model_sha256']) {
            $matches=@($Models | Where-Object { $_.sha256 -ceq $State.model_sha256 -and $_.file_size_bytes -eq $Entry.bytes })
        } elseif ($Entry.identity -ne '-') {
            $matches=@($Models | Where-Object { $_.sha256 -ceq $Entry.identity -and $_.file_size_bytes -eq $Entry.bytes })
        } else {
            # A legacy alias with no receipt is only a candidate. Its content
            # must be verified on Windows before it can be removed.
            $matches=@($Models | Where-Object { $_.file_size_bytes -eq $Entry.bytes })
        }
    }
    if ($matches.Count -eq 1) { return $matches[0] }
    return $null
}
function Save-CardModelBackup($Entry,$Model,[switch]$VerifyRemote) {
    $backup=Find-LocalModel $Model
    $receipt=Join-Path $script:data ('model-'+$Model.id+'.json')
    if ($backup) { Assert-ModelFile $backup $Model $receipt }
    if ($backup -and !$VerifyRemote) { return $backup }
    if ($Entry.bytes -ne $Model.file_size_bytes -or $Entry.path.EndsWith('.part')) {
        throw "Cannot remove $($Entry.path): no verified complete Windows backup exists. Restore $($Model.filename) in this installation's app/models folder and retry Load."
    }
    $cache=Join-Path $script:connection.project_dir 'models'
    $null=New-Item -ItemType Directory -Path $cache -Force
    $temp=Join-Path $cache ('phi-cache-recovered-'+[Guid]::NewGuid().ToString('N')+'.part')
    $tempReceipt=$temp+'.json'
    try {
        Set-JobStatus ('Saving/verifying the old card model on Windows before releasing GDDR: '+$Model.label)
        $tick={param([double]$ElapsedSeconds); Update-LoadTemperature}
        $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+@(($script:target+':'+$Entry.path),$temp)) 900 -OnTick $tick
        Assert-ModelFile $temp $Model $tempReceipt
        if (!$backup) {
            $backup=Join-Path $cache $Model.filename
            # Do not overwrite a file another application published meanwhile.
            if (Test-Path -LiteralPath $backup) { Assert-ModelFile $backup $Model $receipt }
            else {
                [IO.File]::Move($temp,$backup)
                $file=Get-Item -LiteralPath $backup
                Write-JsonFile $receipt ([pscustomobject]@{path=$file.FullName;bytes=$file.Length;modified_ticks=$file.LastWriteTimeUtc.Ticks;sha256=$Model.sha256})
            }
        }
        return $backup
    } finally { Remove-Item -LiteralPath $temp,$tempReceipt -Force -ErrorAction SilentlyContinue }
}
function Remove-OtherCardModels($Selected,$State) {
    if (!$script:cardLockOwned) { throw 'Cache cleanup requires the workload lock.' }
    $tool='/tmp/phi-chat-cache-'+$script:cardLockToken+'.sh'
    $models=@(Get-ChildItem -LiteralPath (Join-Path $script:root 'config/models') -Filter '*.yaml' | ForEach-Object { Get-ModelProfile $script:root $_.BaseName })
    $models+=@($models | Where-Object {Test-ImageModel $_} | ForEach-Object {Get-ProjectorProfile $_})
    $events=New-Object Collections.Generic.List[object]
    $removedBytes=0L; $removed=0; $before=$null; $after=$null
    try {
        Send-CardFiles @((Join-Path $script:root 'scripts/model-cache.sh')) $tool
        $before=Read-MemorySnapshot (Invoke-Card 'cat /proc/meminfo')
        $inventory=@(Read-CardCacheInventory $tool)
        Write-Utf8 (Join-Path $script:job 'model-cache-before.json') (ConvertTo-Json -InputObject $inventory -Depth 5)
        # Keep at most one valid selected-model copy in the current runtime.
        $keep=''
        foreach ($entry in $inventory) {
            if ($entry.path -ceq ($State.remote_base+'/models/'+$Selected.id+'.gguf') -and $entry.identity -ceq $Selected.sha256 -and $entry.bytes -eq $Selected.file_size_bytes) { $keep=$entry.path }
        }
        # Standalone bootstrap receipts contain no bundled model identity.
        if (!$keep -and $State.PSObject.Properties['model_sha256'] -and $Selected.sha256 -ceq $State.model_sha256) {
            $candidate=@($inventory | Where-Object { $_.path -ceq ($State.remote_base+'/model.gguf') -and $_.bytes -eq $Selected.file_size_bytes })
            if ($candidate.Count -eq 1) { $keep=$candidate[0].path }
        }
        foreach ($entry in $inventory) {
            Assert-JobActive
            Update-LoadTemperature
            if ($entry.path -ceq $keep) { continue }
            if (Test-ImageModel $Selected) {
                $p=Get-ProjectorProfile $Selected
                if ($entry.path -ceq ($State.remote_base+'/models/'+$p.id+'.gguf') -and $entry.identity -ceq $p.sha256 -and $entry.bytes -eq $p.file_size_bytes) { continue }
            }
            $model=Get-CacheModel $entry $models $State
            if ($null -eq $model) {
                $events.Add([pscustomobject]@{action='retained';card_path=$entry.path;bytes=$entry.bytes;reason='Unrecognized model; preserved.'})
                continue
            }
            # An old generic model.gguf without an identity receipt is hashed
            # on Windows once; filename/size alone never authorizes its removal.
            $verify=($entry.path.EndsWith('/model.gguf') -and ($entry.path -cne ($State.remote_base+'/model.gguf') -or !$State.PSObject.Properties['model_sha256']) -and $entry.identity -ceq '-')
            if ($entry.identity -ne '-' -and $entry.identity -cne $model.sha256) {
                if ($entry.path -ceq ($State.remote_base+'/models/'+$Selected.id+'.gguf') -or ((Test-ImageModel $Selected) -and $entry.path -ceq ($State.remote_base+'/models/'+$Selected.id+'-projector.gguf'))) { throw 'Selected cache path has a different model identity. File preserved; inspect model-cache-before.json.' }
                $events.Add([pscustomobject]@{action='retained';card_path=$entry.path;bytes=$entry.bytes;reason='Identity differs from pinned model; preserved.'})
                continue
            }
            $backup=Save-CardModelBackup $entry $model -VerifyRemote:$verify
            Set-JobStatus ('Releasing old model from GDDR: '+$model.label+'; Windows backup retained.')
            $answer=Invoke-Card "bash '$tool' remove '$($script:cfg.source_commit)' '$($script:cardLockToken)' '$($entry.path)' '$($entry.bytes)' '$($entry.identity)'"
            if ($answer.Trim() -cne ("REMOVED`t"+$entry.path+"`t"+$entry.bytes)) { throw 'Model removal was not confirmed; inspect cache-cleanup.json.' }
            $removed++; $removedBytes+=$entry.bytes
            $event=[pscustomobject]@{action='removed';model=$model.id;card_path=$entry.path;bytes=$entry.bytes;windows_backup=$backup}
            $events.Add($event)
            $event | Export-Csv -LiteralPath (Join-Path $script:job 'released-model-cache.csv') -Append -NoTypeInformation
        }
        $remaining=@(Read-CardCacheInventory $tool)
        Write-Utf8 (Join-Path $script:job 'model-cache-after.json') (ConvertTo-Json -InputObject $remaining -Depth 5)
        foreach ($entry in $events) {
            if ($entry.action -ceq 'removed' -and @($remaining | Where-Object { $_.path -ceq $entry.card_path }).Count) { throw 'A removed model reappeared during cache cleanup.' }
        }
        $after=Read-MemorySnapshot (Invoke-Card 'cat /proc/meminfo')
        $retained=@($events | Where-Object { $_.action -ceq 'retained' })
        $script:cacheSummary="Removed $removed old/duplicate/partial model files ($([math]::Round($removedBytes/1MB)) MiB of file data); allocatable GDDR $([math]::Round($before.available_kib/1024)) -> $([math]::Round($after.available_kib/1024)) MiB."
        if ($retained.Count) { $script:cacheSummary+=" Retained $($retained.Count) unrecognized files; see cache-cleanup.json." }
        Set-JobStatus $script:cacheSummary
    } finally {
        Write-JsonFile (Join-Path $script:job 'cache-cleanup.json') ([pscustomobject]@{removed_files=$removed;removed_file_bytes=$removedBytes;before=$before;after=$after;events=@($events.ToArray());note='File bytes removed and measured allocatable-memory change are distinct; no cache-drop or process-kill operation.'})
        $prior=$script:cleanupMode; $script:cleanupMode=$true
        try { $null=Invoke-Card "rm -f '$tool'" }
        catch { Write-Utf8 (Join-Path $script:job 'cache-tool-cleanup-warning.txt') $_.Exception.Message }
        finally { $script:cleanupMode=$prior }
    }
}
