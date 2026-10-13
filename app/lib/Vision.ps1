function Get-ProjectorProfile($Model) {
    if (!(Test-ImageModel $Model)) { return $null }
    $p=$Model.projector
    if ($p.filename -cnotmatch '^[A-Za-z0-9_.-]+\.gguf$' -or $p.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $p.file_size_bytes -lt 1) { throw 'Invalid pinned vision projector.' }
    $local=($p.PSObject.Properties['local_only'] -and $p.local_only)
    return [pscustomobject]@{id=($Model.id+'-projector');label='Step3 vision projector';filename=$p.filename;file_size_bytes=$p.file_size_bytes;sha256=$p.sha256;repository=$Model.repository;revision=$Model.revision;model_path=('models/uniform-q5-k/'+$p.filename);local_only=$local}
}
function Install-CardProjector($Model,$State,[string]$Local) {
    if (!$script:cardLockOwned) { throw 'Projector staging requires the card lease.' }
    $p=Get-ProjectorProfile $Model; $path=$State.remote_base+'/models/'+$p.id+'.gguf'
    $present=Get-RemoteModelIdentity $path
    if (($present -split '\s+') -join ' ' -ceq "$($p.sha256) $($p.file_size_bytes)") { return $path }
    $available=Read-MemorySnapshot (Invoke-Card 'cat /proc/meminfo')
    if ($available.available_kib*1024 -lt $p.file_size_bytes+($Model.estimated_peak_runtime_mib+$script:health.profile.available_reserve_mib)*1MB) { throw 'Not enough free card memory to load the vision projector.' }
    try {
        Send-ModelFile $Local ($path+'.part') $p.file_size_bytes
        $null=Invoke-Card "mv '$path.part' '$path' && printf '%s\n' '$($p.sha256)' > '$path.identity'"
    } catch {
        $prior=$script:cleanupMode; $script:cleanupMode=$true
        try { $null=Invoke-Card "rm -f '$path.part'" } finally { $script:cleanupMode=$prior }
        throw
    }
    return $path
}
function Get-VisionResourceModel($Model,[object[]]$Images=@()) {
    if (!(Test-ImageModel $Model)) { return $Model }
    $copy=$Model.PSObject.Copy()
    $projectorMiB=[long][math]::Ceiling($Model.projector.file_size_bytes/1MB)
    $copy | Add-Member extra_resident_mib $projectorMiB -Force
    if ($Images.Count -gt 0) {
        # mtmd copies projector tensors. Charge the RAM-backed file separately.
        # Reserve the 728px Step3 vision graph and all decoded 4096px RGB inputs.
        $imageBytes=0L
        foreach ($image in $Images) { $imageBytes+=12L*$image.width*$image.height+2L*$image.bytes }
        $copy.estimated_peak_runtime_mib+=$projectorMiB+1024+[math]::Ceiling($imageBytes/1MB)
        $copy | Add-Member vision_active $true -Force
    }
    $copy.minimum_memory_mib=[long][math]::Max($copy.minimum_memory_mib,([math]::Ceiling($copy.file_size_bytes/1MB)+$projectorMiB+$copy.estimated_peak_runtime_mib))
    return $copy
}
function Assert-PreparedProjector($Ready,$Model,$State) {
    $p=Get-ProjectorProfile $Model; $expected=$State.remote_base+'/models/'+$p.id+'.gguf'
    if (!$Ready.PSObject.Properties['remote_projector'] -or $Ready.remote_projector -cne $expected -or $Ready.projector_sha256 -cne $p.sha256) { Stop-ChatInput 'Reload Step3-VL to prepare its matching vision projector.' }
    $present=Get-RemoteModelIdentity $expected
    if (($present -split '\s+') -join ' ' -cne "$($p.sha256) $($p.file_size_bytes)") { Stop-ChatInput 'The vision projector is no longer loaded. Reload Step3-VL.' }
    return $expected
}
