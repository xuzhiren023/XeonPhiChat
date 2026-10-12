# Pure accounting; keep the legacy-kernel formula in sync with memory-info.awk.
function Read-MemorySnapshot([string]$Text) {
    $values=@{}
    $names=@('MemTotal','MemFree','MemAvailable','Cached','Shmem','Unevictable','Dirty','Writeback','Active(file)','Inactive(file)')
    foreach ($name in $names) {
        $rows=[regex]::Matches($Text,'(?m)^'+[regex]::Escape($name)+':\s*([^\r\n]+)')
        if (!$rows.Count) { continue }
        if ($rows.Count -ne 1 -or $rows[0].Groups[1].Value.Trim() -notmatch '^([0-9]+)\s+kB$') { throw "Invalid memory telemetry: $name." }
        $values[$name]=[long]$Matches[1]
    }
    if (!$values.ContainsKey('MemTotal') -or !$values.ContainsKey('MemFree') -or
        $values.MemTotal -le 0 -or $values.MemFree -gt $values.MemTotal) { throw 'Missing or inconsistent memory telemetry.' }
    foreach ($name in $values.Keys) {
        if ($values[$name] -gt $values.MemTotal) { throw "Inconsistent memory telemetry: $name exceeds total RAM." }
    }
    $credit=0L; $available=$values.MemFree; $method='MemFree only (incomplete cache telemetry)'
    if ($values.ContainsKey('MemAvailable')) {
        $available=$values.MemAvailable; $method='kernel MemAvailable'
    } else {
        $complete=$true
        foreach ($name in @('Cached','Shmem','Unevictable','Dirty','Writeback','Active(file)','Inactive(file)')) {
            if (!$values.ContainsKey($name)) { $complete=$false }
        }
        if ($complete) {
            # RAM-backed files are not free memory. Bound clean file-cache credit
            # by both Cached minus non-reclaimable pages and the file LRU size.
            # Do not credit buffers, reclaimable slab or swap on this old kernel.
            $fileLru=$values['Active(file)']+$values['Inactive(file)']
            $credit=[long][math]::Max(0,([math]::Min(($values.Cached-$values.Shmem-$values.Unevictable),$fileLru)-$values.Dirty-$values.Writeback))
            $available=[long][math]::Min($values.MemTotal,($values.MemFree+$credit))
            $method='legacy conservative estimate'
        }
    }
    return [pscustomobject]@{total_kib=$values.MemTotal;free_kib=$values.MemFree;available_kib=$available;cache_credit_kib=$credit;method=$method}
}
function Get-MemoryRequirement($Model,$Profile,[switch]$IncludeModelFile) {
    if ($Model.PSObject.Properties['architecture'] -and $Model.architecture -ceq 'lfm2moe') {
        throw 'LFM2-MoE runtime memory is unqualified. All expert weights remain resident; active-expert count is not a memory budget.'
    }
    Assert-ModelBudget $Model $Profile
    $fileMiB=if ($IncludeModelFile) { [long][math]::Ceiling($Model.file_size_bytes/1MB) } else { 0L }
    $runtimeMiB=[long]$Model.estimated_peak_runtime_mib
    $reserveMiB=[long]$Profile.available_reserve_mib
    if ($reserveMiB -lt 256) { throw 'Memory reserve must be at least 256 MiB.' }
    return [pscustomobject]@{model_file_mib=$fileMiB;runtime_mib=$runtimeMiB;reserve_mib=$reserveMiB;required_mib=($fileMiB+$runtimeMiB+$reserveMiB)}
}
