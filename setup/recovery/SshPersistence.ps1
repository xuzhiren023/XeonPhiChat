. (Join-Path $PSScriptRoot 'Primitives.ps1')

function Protect-IdentityDirectory([string]$Path) {
    $drive=New-Object IO.DriveInfo([IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path)))
    if ($drive.DriveFormat -ne 'NTFS') { throw 'SSH identity storage requires a local NTFS directory for private-key permissions.' }
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $inherit=[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit'
    $allow=[Security.AccessControl.AccessControlType]::Allow
    $prop=[Security.AccessControl.PropagationFlags]::None
    $owner=[Security.Principal.WindowsIdentity]::GetCurrent().User
    # Set only permissions; keep the existing Windows owner.
    foreach ($sid in @($owner,(New-Object Security.Principal.SecurityIdentifier('S-1-5-18')),(New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))) {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid,[Security.AccessControl.FileSystemRights]::FullControl,$inherit,$prop,$allow)))
    }
    [IO.Directory]::SetAccessControl($Path,$acl)
}
function Protect-IdentityFile([string]$Path) {
    # Replace the DACL instead of editing an MPSS-inherited ACL. Some Intel
    # files have noncanonical ACE ordering that Windows refuses to edit.
    $acl=New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true,$false)
    # ssh-keygen creates the file for this user. Change its DACL only; asking
    # Windows to rewrite its owner also requires privileges a normal user lacks.
    $owner=[Security.Principal.WindowsIdentity]::GetCurrent().User
    foreach ($sid in @($owner,(New-Object Security.Principal.SecurityIdentifier('S-1-5-18')),(New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))) {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid,[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow)))
    }
    [IO.File]::SetAccessControl($Path,$acl)
}
function Assert-RegularPath([string]$Path) {
    $cursor=[IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse points are unsupported for SSH boot files: $cursor" }
        }
        $parent=Split-Path $cursor -Parent
        if ($parent -eq $cursor) { break }; $cursor=$parent
    }
}
function Read-SmallText([string]$Path) {
    Assert-RegularPath $Path
    if ((Get-Item -LiteralPath $Path).Length -gt 2MB) { throw "Unexpectedly large configuration file: $Path" }
    return [IO.File]::ReadAllText($Path)
}
function Get-PublicKey([string]$Text) {
    $line=$Text.Trim()
    $m=[regex]::Match($line,'\A(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(?:256|384|521)) ([A-Za-z0-9+/]+={0,2})(?: [^\r\n]*)?\z')
    if (!$m.Success) { throw 'Invalid single OpenSSH public key.' }
    $blob=[Convert]::FromBase64String($m.Groups[2].Value)
    if ($blob.Length -lt 20) { throw 'Truncated public key.' }
    $count=[Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($blob,0))
    if ($count -lt 1 -or $count -gt 40 -or ($count+4) -ge $blob.Length -or [Text.Encoding]::ASCII.GetString($blob,4,$count) -cne $m.Groups[1].Value) { throw 'Public key algorithm and blob disagree.' }
    if ($m.Groups[1].Value -ceq 'ssh-ed25519' -and ($blob.Length -ne 51 -or [Net.IPAddress]::NetworkToHostOrder([BitConverter]::ToInt32($blob,15)) -ne 32)) { throw 'Malformed ED25519 key.' }
    $sha=[Security.Cryptography.SHA256]::Create()
    try { $fingerprint='SHA256:'+([Convert]::ToBase64String($sha.ComputeHash($blob))).TrimEnd('=') } finally { $sha.Dispose() }
    return [pscustomobject]@{type=$m.Groups[1].Value;blob=$m.Groups[2].Value;public=($m.Groups[1].Value+' '+$m.Groups[2].Value);fingerprint=$fingerprint}
}
function Get-FilelistEntries([string]$Text) {
    $index=0
    foreach ($line in ($Text -split '\r?\n')) {
        $index++
        if ($line -match '^\s*(#|$)') { continue }
        $fields=@($line.Trim() -split '\s+')
        if ($fields.Count -lt 2) { throw "Malformed MPSS filelist line $index" }
        [pscustomobject]@{kind=$fields[0];target=$fields[1];fields=$fields;line=$line;number=$index}
    }
}
function Read-BootFile([string]$Mpss,[string]$Target) {
    $answer=$null
    foreach ($name in @('common','mic0')) {
        $list=Join-Path $Mpss ('filesystem/'+$name+'.filelist')
        if (!(Test-Path -LiteralPath $list -PathType Leaf)) { continue }
        $entries=@(Get-FilelistEntries (Read-SmallText $list) | Where-Object target -CEQ $Target)
        if ($entries.Count -gt 1) { throw "Duplicate $Target entries in $list. Preserve and review this filelist before repair." }
        if ($entries.Count) {
            $entry=$entries[0]
            if ($entry.kind -cne 'file' -or $entry.fields.Count -lt 6) { throw "Unsupported boot-file mapping for $Target in $list" }
            $source=Join-Safe (Join-Path $Mpss ('filesystem/'+$name)) $entry.fields[2]
            $answer=[pscustomobject]@{path=$source;text=(Read-SmallText $source)}
        }
    }
    return $answer
}
function Merge-AuthorizedKey([string]$Existing,$Key) {
    foreach ($line in ($Existing -split '\r?\n')) {
        if ($line -match '^\s*(#|$)') { continue }
        $m=[regex]::Match($line,'(?:^|\s)'+[regex]::Escape($Key.type)+'\s+'+[regex]::Escape($Key.blob)+'(?:\s|$)')
        if ($m.Success) {
            if (!$line.TrimStart().StartsWith($Key.type+' ',[StringComparison]::Ordinal)) { throw 'This login key already has authorized_keys restrictions. Repair will not remove or bypass them.' }
            return $Existing.TrimEnd("`r","`n")+"`n"
        }
    }
    return $Existing.TrimEnd("`r","`n")+$(if ($Existing.Trim()) {"`n"} else {''})+$Key.public+" phi-chat-login`n"
}
function Add-Ed25519HostConfig([string]$Existing) {
    if ($Existing -match '(?im)^\s*Include\s') { throw 'sshd_config uses Include; inspect the included configuration before automatic persistence.' }
    if ($Existing -match '(?im)^\s*(PermitRootLogin|PubkeyAuthentication)\s+no(?:\s|$)') { throw 'Existing SSH configuration disables root/key login; it will not be weakened automatically.' }
    foreach ($m in [regex]::Matches($Existing,'(?im)^\s*AuthorizedKeysFile\s+([^\r\n#]+)')) {
        $paths=@($m.Groups[1].Value.Trim() -split '\s+')
        if ('.ssh/authorized_keys' -cnotin $paths -and '/root/.ssh/authorized_keys' -cnotin $paths -and '%h/.ssh/authorized_keys' -cnotin $paths) { throw 'Custom AuthorizedKeysFile location is unsupported; no SSH policy was changed.' }
    }
    $hostKeys=@([regex]::Matches($Existing,'(?im)^\s*HostKey\s+([^\s#]+)') | ForEach-Object { $_.Groups[1].Value.Trim('"') })
    # With no explicit HostKey directives, OpenSSH uses its default key files.
    if (!$hostKeys.Count -or '/etc/ssh/ssh_host_ed25519_key' -cin $hostKeys) { return $Existing }
    return "# Phi Chat persistent server identity`nHostKey /etc/ssh/ssh_host_ed25519_key`n"+$Existing
}
function New-IdentityFilelist([string]$Current,[string]$Common,[hashtable]$Mappings) {
    $all=@(Get-FilelistEntries $Common)+@(Get-FilelistEntries $Current)
    $directories=@('/etc','/etc/ssh','/root','/root/.ssh')
    foreach ($entry in $all) {
        if ($entry.target -cin $directories -and $entry.kind -cne 'dir') { throw "Non-directory boot mapping at $($entry.target); no changes made." }
        if ($Mappings.ContainsKey($entry.target) -and $entry.kind -cne 'file') { throw "Non-file boot mapping at $($entry.target); no changes made." }
    }
    $keep=New-Object 'Collections.Generic.List[string]'
    foreach ($line in ($Current -split '\r?\n')) {
        if ($line -match '^\s*(#|$)') { $keep.Add($line); continue }
        $fields=@($line.Trim() -split '\s+')
        if (!$Mappings.ContainsKey($fields[1])) { $keep.Add($line) }
    }
    $result=($keep -join "`n").TrimEnd("`r","`n")+"`n"
    foreach ($dir in $directories) {
        if ($dir -cnotin @($all | ForEach-Object { $_.target })) { $mode=if ($dir.StartsWith('/root')) {'700'} else {'755'}; $result+="dir $dir $mode 0 0`n" }
    }
    foreach ($target in @($Mappings.Keys | Sort-Object)) {
        $m=$Mappings[$target]
        $result+="file $target $($m.source) $($m.mode) 0 0`n"
    }
    return $result
}
function Get-IdentityInput([string]$Path) {
    Assert-RegularPath $Path
    if (!(Test-Path -LiteralPath $Path)) { return [pscustomobject]@{path=$Path;exists=$false;sha256=''} }
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Expected a regular input file: $Path" }
    return [pscustomobject]@{path=$Path;exists=$true;sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
}
function Assert-IdentityInputs($Inputs) {
    foreach ($inputFile in $Inputs) {
        $now=Get-IdentityInput $inputFile.path
        if ($now.exists -ne $inputFile.exists -or $now.sha256 -cne $inputFile.sha256) { throw "File changed after the plan was prepared: $($inputFile.path). Prepare a new plan." }
    }
}
function Get-HostEntryMatch([string]$Token,[string]$Address) {
    if ($Token -ceq $Address -or $Token -ceq ('['+$Address+']:22')) { return $true }
    if ($Token.StartsWith('|1|')) {
        $parts=$Token.Split('|')
        if ($parts.Count -ne 4) { throw 'Malformed hashed known_hosts entry.' }
        $mac=New-Object Security.Cryptography.HMACSHA1
        try {
            $mac.Key=[Convert]::FromBase64String($parts[2])
            foreach ($value in @($Address,('['+$Address+']:22'))) {
                if ([Convert]::ToBase64String($mac.ComputeHash([Text.Encoding]::UTF8.GetBytes($value))) -ceq $parts[3]) { return $true }
            }
        } finally { $mac.Dispose() }
    }
    return $false
}
function Set-CardKnownHostsText([string]$Existing,[string]$Address,$Key) {
    Assert-PrivateAddress $Address
    $lines=New-Object 'Collections.Generic.List[string]'
    foreach ($line in ($Existing -split '\r?\n')) {
        if ($line -match '^\s*(#|$)') { $lines.Add($line); continue }
        $m=[regex]::Match($line,'^(\s*)(?:(@\S+)\s+)?(\S+)(\s+.*)$')
        if (!$m.Success) { throw 'Cannot safely parse known_hosts; existing file was preserved.' }
        $hosts=@($m.Groups[3].Value.Split(',')); $remaining=New-Object 'Collections.Generic.List[string]'; $matched=$false
        if ($m.Groups[2].Success) {
            foreach ($token in $hosts) {
                $pattern=New-Object Management.Automation.WildcardPattern($token.TrimStart('!'),[Management.Automation.WildcardOptions]::IgnoreCase)
                if ((Get-HostEntryMatch $token $Address) -or $pattern.IsMatch($Address)) { throw 'A marked/revoked/cert-authority entry applies to the card. Review it manually; repair will not override it.' }
            }
        }
        foreach ($token in $hosts) {
            if (Get-HostEntryMatch $token $Address) { $matched=$true } else { $remaining.Add($token) }
        }
        if (!$matched) { $lines.Add($line); continue }
        if ($m.Groups[2].Success) { throw 'A marked/revoked/cert-authority entry applies to the card. Review it manually; repair will not override it.' }
        if ($remaining.Count) { $lines.Add($m.Groups[1].Value+($remaining -join ',')+$m.Groups[4].Value) }
    }
    return (($lines -join "`n").TrimEnd("`r","`n")+"`n"+$Address+' '+$Key.public+" phi-chat-mic0`n").TrimStart("`r","`n")
}
function New-SshPersistencePlan([string]$Recovery,[string]$PlanDir,[string]$Identity,[string]$PublicKey,[string]$ClientPublicKey,[string]$Serial) {
    $settings=Read-Json (Join-Path $Recovery 'data/settings.yaml')
    $connection=Read-Json (Join-Path $Recovery 'data/app/config/connection.yaml')
    $mpss=Resolve-Absolute $settings.mpss_dir
    Assert-RegularPath $mpss
    Assert-PrivateAddress $connection.card_address
    $micList=Join-Path $mpss 'filesystem/mic0.filelist'
    if (!(Test-Path -LiteralPath $micList -PathType Leaf)) { throw "Standard MPSS filelist is missing: $micList. No boot files changed. Preserve your actual MPSS layout for review." }
    foreach ($relative in @('mic0.xml','bin/micctrl.exe','bin/micinfo.exe')) {
        if (!(Test-Path -LiteralPath (Join-Path $mpss $relative) -PathType Leaf)) { throw "Required MPSS file is missing: $relative" }
    }
    $images=@(Get-TreeFiles $mpss @('*.log','*.log.*') | Where-Object Name -Match '^mic0\.image(?:\.gz)?$')
    if (!$images.Count) { throw 'No existing mic0.image or mic0.image.gz found under MPSS. Custom boot-image layouts need review; no boot files changed.' }
    $hostKey=Get-PublicKey $PublicKey
    if ($hostKey.type -cne 'ssh-ed25519') { throw 'This repair requires an ED25519 server key.' }
    $clientKey=Get-PublicKey $ClientPublicKey
    $passwd=Read-BootFile $mpss '/etc/passwd'
    if ($passwd) {
        $rootLines=@($passwd.text -split '\r?\n' | Where-Object { $_ -match '^root:' })
        if ($rootLines.Count -ne 1 -or $rootLines[0] -notmatch '^root:[^:]*:0:0:[^:]*:/root:') { throw 'Nonstandard root account/home in the boot overlay. No automatic account changes.' }
    }
    $authorized=Read-BootFile $mpss '/root/.ssh/authorized_keys'
    $sshd=Read-BootFile $mpss '/etc/ssh/sshd_config'
    $authText=if ($authorized) { $authorized.text } else { '' }
    $common=Join-Path $mpss 'filesystem/common.filelist'
    $commonText=if (Test-Path -LiteralPath $common) { Read-SmallText $common } else { '' }
    $marker='phi-chat-ssh-v1:'+([Guid]::NewGuid().ToString('N'))
    $payload=Join-Path $PlanDir 'payload'; New-Directory $payload
    Copy-Item -LiteralPath (Join-Path $Identity 'ssh_host_ed25519_key') -Destination (Join-Path $payload 'ssh_host_ed25519_key')
    Write-Utf8 (Join-Path $payload 'ssh_host_ed25519_key.pub') ($hostKey.public+" phi-chat-mic0`n")
    Write-Utf8 (Join-Path $payload 'authorized_keys') (Merge-AuthorizedKey $authText $clientKey)
    Write-Utf8 (Join-Path $payload 'receipt.txt') ($marker+"`n")
    $mappings=@{
        '/etc/ssh/ssh_host_ed25519_key'=@{source='phi-chat-identity/ssh_host_ed25519_key';mode='600'}
        '/etc/ssh/ssh_host_ed25519_key.pub'=@{source='phi-chat-identity/ssh_host_ed25519_key.pub';mode='644'}
        '/root/.ssh/authorized_keys'=@{source='phi-chat-identity/authorized_keys';mode='600'}
        '/etc/phi-chat-identity'=@{source='phi-chat-identity/receipt.txt';mode='644'}
    }
    if ($sshd) {
        $newConfig=Add-Ed25519HostConfig $sshd.text
        if ($newConfig -cne $sshd.text) {
            Write-Utf8 (Join-Path $payload 'sshd_config') $newConfig
            $mappings['/etc/ssh/sshd_config']=@{source='phi-chat-identity/sshd_config';mode='600'}
        }
    }
    $nextList=New-IdentityFilelist (Read-SmallText $micList) $commonText $mappings
    Write-Utf8 (Join-Path $payload 'mic0.filelist') $nextList
    $writes=New-Object Collections.ArrayList
    $null=$writes.Add([pscustomobject]@{source='mic0.filelist';relative='filesystem/mic0.filelist'})
    foreach ($file in @(Get-ChildItem -LiteralPath $payload -File | Where-Object Name -CNE 'mic0.filelist')) {
        $null=$writes.Add([pscustomobject]@{source=$file.Name;relative=('filesystem/mic0/phi-chat-identity/'+$file.Name)})
    }
    $inputPaths=@($micList,$common,(Join-Path $mpss 'global.xml'),(Join-Path $mpss 'mic0.xml'))
    foreach ($item in @($authorized,$sshd,$passwd)) { if ($item) { $inputPaths+=$item.path } }
    foreach ($write in $writes) { $inputPaths+=Join-Safe $mpss $write.relative }
    $inputPaths+=@($images.FullName)
    $inputs=@($inputPaths | Select-Object -Unique | ForEach-Object { Get-IdentityInput $_ })
    $payloadInputs=@(Get-ChildItem -LiteralPath $payload -File | ForEach-Object { Get-IdentityInput $_.FullName })
    $plan=[pscustomobject]@{schema_version=1;recovery=$Recovery;mpss=$mpss;serial=$Serial;address=$connection.card_address;public_key=$hostKey.public;fingerprint=$hostKey.fingerprint;client_fingerprint=$clientKey.fingerprint;marker=$marker;created_utc=[DateTime]::UtcNow.ToString('o');writes=@($writes);inputs=$inputs;payload_inputs=$payloadInputs;images=@($images.FullName);sshd_overlay_read=[bool]$sshd}
    Save-Json (Join-Path $PlanDir 'plan.json') $plan
    $preview="SSH PERSISTENCE PLAN`nCard: mic0; serial $Serial; address $($connection.card_address)`nServer identity stored on Windows: $($hostKey.fingerprint)`nExisting Windows login key: $($clientKey.fingerprint)`n`nMPSS file writes:`n"
    foreach ($write in $writes) { $preview+='  '+(Join-Safe $mpss $write.relative)+"`n" }
    $preview+="`nManaged filelist entries (unrelated entries remain):`n"
    foreach ($entry in @(Get-FilelistEntries $nextList | Where-Object { $mappings.ContainsKey($_.target) })) { $preview+='  '+$entry.line+"`n" }
    $preview+="`nGenerated image files to back up:`n"+($images.FullName -join "`n")+"`n"
    if ($mappings.ContainsKey('/etc/ssh/sshd_config')) { $preview+="Add global HostKey /etc/ssh/ssh_host_ed25519_key; retain other SSH settings.`n" }
    if (!$sshd) { $preview+="No sshd_config overlay found; standard OpenSSH default key/authorized_keys paths are assumed. Boot verification must prove them.`n" }
    $preview+="`nCommand: `"$(Join-Path $mpss 'bin/micctrl.exe')`" -g mic0`n"
    $preview+="Optional restart: micctrl.exe -r mic0, wait for ready, then micctrl.exe -b mic0.`nRestart discards every file/process stored only in card RAM. Save work first. Accepted Windows runtime/models are retained.`n"
    $preview+="Verify the new identity using this installation's private known_hosts. The Windows user's global SSH trust and existing private keys are not changed.`nNetwork configuration is handled by the separate recorded setup transaction. No kernel, firmware, fan or SSH security-disable setting changes.`n"
    $preview+="Private identity files and generated mic0 images receive NTFS permissions for the current account, SYSTEM and Administrators.`n"
    Write-Utf8 (Join-Path $PlanDir 'changes.txt') $preview
    return $plan
}
function Read-SshPersistencePlan([string]$PlanDir) {
    Assert-RegularPath $PlanDir
    $plan=Read-Json (Join-Path $PlanDir 'plan.json')
    if ($plan.schema_version -ne 1 -or $plan.marker -notmatch '^phi-chat-ssh-v1:[a-f0-9]{32}$') { throw 'Unsupported SSH persistence plan.' }
    $settings=Read-Json (Join-Path $plan.recovery 'data/settings.yaml')
    if ((Resolve-Absolute $settings.mpss_dir) -cne $plan.mpss -or !(Test-Within $PlanDir (Join-Path $plan.recovery 'data/ssh-repair'))) { throw 'Plan does not belong to this recovery/MPSS installation.' }
    $connection=Read-Json (Join-Path $plan.recovery 'data/app/config/connection.yaml')
    Assert-PrivateAddress $plan.address
    if ($connection.card_address -cne $plan.address) { throw 'Card address changed since the plan was prepared.' }
    $key=Get-PublicKey $plan.public_key
    if ($key.type -cne 'ssh-ed25519' -or $key.fingerprint -cne $plan.fingerprint) { throw 'Invalid saved server identity.' }
    foreach ($write in $plan.writes) {
        if ($write.relative -cne 'filesystem/mic0.filelist' -and $write.relative -notmatch '^filesystem/mic0/phi-chat-identity/(ssh_host_ed25519_key(?:\.pub)?|authorized_keys|receipt\.txt|sshd_config)$') { throw 'Unapproved MPSS write target.' }
        if ($write.source -cne (Split-Path $write.relative -Leaf)) { throw 'Invalid payload mapping.' }
        $null=Join-Safe $plan.mpss $write.relative
    }
    foreach ($imagePath in $plan.images) {
        if (!(Test-Within $imagePath $plan.mpss) -or (Split-Path $imagePath -Leaf) -notmatch '^mic0\.image(?:\.gz)?$') { throw 'Invalid image backup target.' }
    }
    foreach ($inputFile in $plan.inputs) { if (!(Test-Within $inputFile.path $plan.mpss)) { throw 'Input outside MPSS.' } }
    foreach ($inputFile in $plan.payload_inputs) { if (!(Test-Within $inputFile.path (Join-Path $PlanDir 'payload'))) { throw 'Payload outside the plan.' } }
    return $plan
}
function Get-RepairAcl([string]$Path) {
    $access=[Security.AccessControl.AccessControlSections]::Access
    return [IO.File]::GetAccessControl($Path,$access).GetSecurityDescriptorSddlForm($access)
}
function Set-RepairAcl([string]$Path,[string]$Sddl) {
    $acl=New-Object Security.AccessControl.FileSecurity
    # Old journals include owner/group fields. Ignore those too: setup changes
    # permissions, not ownership, and restoring SYSTEM ownership needs privileges
    # that ordinary UAC elevation does not grant.
    $acl.SetSecurityDescriptorSddlForm($Sddl,[Security.AccessControl.AccessControlSections]::Access)
    [IO.File]::SetAccessControl($Path,$acl)
}
function Backup-IdentityTargets($Plan,[string]$PlanDir) {
    $backup=Join-Path $PlanDir 'before'; New-Directory $backup
    $paths=@($Plan.writes | ForEach-Object { Join-Safe $Plan.mpss $_.relative })+@($Plan.images)+@((Join-Path $Plan.mpss 'global.xml'),(Join-Path $Plan.mpss 'mic0.xml'))
    $entries=New-Object Collections.ArrayList; $i=0
    foreach ($path in @($paths | Select-Object -Unique)) {
        $i++; $inputFile=Get-IdentityInput $path
        $item=[pscustomobject]@{path=$path;exists=$inputFile.exists;sha256=$inputFile.sha256;backup=('before/'+$i+'.bin');acl=''}
        if ($item.exists) {
            $item.acl=Get-RepairAcl $path
            $copied=[PhiRecovery.Files]::Copy($path,(Join-Safe $PlanDir $item.backup))
            if ($copied -ine $item.sha256) { throw "Backup changed while copying $path. No boot files changed." }
        }
        $null=$entries.Add($item)
    }
    $journal=[pscustomobject]@{schema_version=1;state='backed-up';entries=@($entries);after=@();failure=''}
    Save-Json (Join-Path $PlanDir 'journal.json') $journal
    return $journal
}
function Restore-IdentityTargets($Journal,[string]$PlanDir) {
    $plan=Read-SshPersistencePlan $PlanDir
    # Backups are private but still validate paths and bytes before writing anything.
    $allowed=@($plan.writes | ForEach-Object { Join-Safe $plan.mpss $_.relative })+@($plan.images)+@((Join-Path $plan.mpss 'global.xml'),(Join-Path $plan.mpss 'mic0.xml'))
    foreach ($entry in $Journal.entries) {
        if ($entry.path -cnotin $allowed) { throw 'Rollback target not in the reviewed plan.' }
        Assert-RegularPath $entry.path
        if ($entry.exists) {
            $copy=Join-Safe $PlanDir $entry.backup
            if ((Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash -ine $entry.sha256) { throw 'Rollback backup is damaged; no restore attempted.' }
        }
    }
    foreach ($entry in $Journal.entries) {
        if ($entry.exists) {
            # A previous rollback may already have restored the bytes before
            # stopping on permissions. Avoid rewriting an unchanged boot image.
            if (!(Test-Path -LiteralPath $entry.path -PathType Leaf) -or (Get-FileHash -LiteralPath $entry.path).Hash -ine $entry.sha256) {
                Copy-Item -LiteralPath (Join-Safe $PlanDir $entry.backup) -Destination $entry.path -Force
            }
            Set-RepairAcl $entry.path $entry.acl
        } elseif (Test-Path -LiteralPath $entry.path -PathType Leaf) { Remove-Item -LiteralPath $entry.path }
    }
    $Journal.state='rolled-back'; Save-Json (Join-Path $PlanDir 'journal.json') $Journal
}
function Apply-SshPersistencePlan([string]$PlanDir,[scriptblock]$Generate) {
    $plan=Read-SshPersistencePlan $PlanDir
    if (Test-Path -LiteralPath (Join-Path $PlanDir 'journal.json')) { throw 'This plan was already attempted. Use Verify/Rollback, or prepare a fresh plan.' }
    Assert-IdentityInputs $plan.inputs; Assert-IdentityInputs $plan.payload_inputs
    $journal=Backup-IdentityTargets $plan $PlanDir
    # Recheck after potentially large image backup, before the first boot-file write.
    Assert-IdentityInputs $plan.inputs; Assert-IdentityInputs $plan.payload_inputs
    $privateBoot=Join-Path $plan.mpss 'filesystem/mic0/phi-chat-identity'
    New-Directory $privateBoot; Protect-IdentityDirectory $privateBoot
    try {
        $journal.state='applying'; Save-Json (Join-Path $PlanDir 'journal.json') $journal
        foreach ($write in $plan.writes) {
            $destination=Join-Safe $plan.mpss $write.relative
            Copy-Item -LiteralPath (Join-Safe (Join-Path $PlanDir 'payload') $write.source) -Destination $destination -Force
            if (Test-Within $destination $privateBoot) { Protect-IdentityFile $destination }
        }
        & $Generate $plan
        $changed=$false
        foreach ($imagePath in $plan.images) {
            $now=Get-IdentityInput $imagePath
            $old=@($plan.inputs | Where-Object path -CEQ $imagePath)[0]
            if (!$now.exists -or (Get-Item -LiteralPath $imagePath).Length -eq 0) { throw 'Image generation left a missing/empty image.' }
            if ($now.sha256 -cne $old.sha256) { $changed=$true }
            Protect-IdentityFile $imagePath
        }
        if (!$changed) { throw 'micctrl returned success but no known mic0 image changed. Boot layout needs review; refusing to reset.' }
        foreach ($name in @('global.xml','mic0.xml')) {
            $path=Join-Path $plan.mpss $name
            Assert-IdentityInputs @($plan.inputs | Where-Object path -CEQ $path)
        }
        $journal.state='image-generated'
        $journal.after=@($journal.entries | ForEach-Object { Get-IdentityInput $_.path })
        Save-Json (Join-Path $PlanDir 'journal.json') $journal
    } catch {
        $journal.failure=$_.Exception.Message
        try { Restore-IdentityTargets $journal $PlanDir }
        catch { $journal.state='rollback-failed'; Save-Json (Join-Path $PlanDir 'journal.json') $journal; throw "Repair failed and rollback also failed. Do not reset mic0. Preserve $PlanDir. $($_.Exception.Message)" }
        throw "Boot-file update failed; reviewed files/images restored. No reset requested. $($journal.failure)"
    }
    return $journal
}
function Restart-MicIdentity([string]$InitialState,[scriptblock]$ReadStatus,[scriptblock]$Reset,[scriptblock]$Boot,[scriptblock]$Wait,[int]$Attempts=90) {
    $transition=$InitialState -ceq 'ready'; $booted=$false
    if ($InitialState -ceq 'online') { & $Reset }
    elseif ($InitialState -cne 'ready') { throw 'Restart requires ready or online mic0.' }
    for ($i=0; $i -lt $Attempts; $i++) {
        $raw=& $ReadStatus
        if ($raw -match '(?im)^\s*mic0\s*:\s*(?:state\s*[:=]\s*)?(resetting|shutdown)\s*(?:\(|$)') { & $Wait; continue }
        $state=Get-MicState $raw
        if ($state -ceq 'ready') {
            $transition=$true
            if (!$booted) { & $Boot; $booted=$true }
        } elseif ($state -ceq 'booting') { $transition=$true }
        elseif ($state -ceq 'online' -and $transition) { return }
        Write-Host "WAIT: reboot state $state ($($i+1)/$Attempts)"
        & $Wait
    }
    throw 'Timed out waiting for an observed mic0 reboot. No second reset was attempted.'
}
