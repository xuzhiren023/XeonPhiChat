# Portable releases resolve paths from the app, never from the working directory.
function Resolve-PhiLocalPath([string]$Root,[string]$Path,[switch]$Contained) {
    if (!$Path) { throw 'Empty application dependency path.' }
    $base=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $full=if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $base $Path)) }
    if ($Contained -and $full -cne $base -and !$full.StartsWith($base+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Portable dependency escapes the application folder.'
    }
    return $full
}
function Read-PhiConnection([string]$Root) {
    $c=Read-JsonFile (Join-Path $Root 'config/connection.yaml')
    $portable=($c.PSObject.Properties['portable'] -and $c.portable -eq $true)
    foreach ($field in @('project_dir','phase3_kit','data_dir','key_path','micinfo','ssh_path','scp_path','tar_path','known_hosts')) {
        if ($c.PSObject.Properties[$field]) {
            # Authentication remains in the user's Windows profile. It is not
            # duplicated into a release or a shareable application archive.
            $externalIdentity=($field -ceq 'key_path' -and $c.PSObject.Properties['identity_location'] -and $c.identity_location -ceq 'windows-profile')
            $systemTool=($field -cin @('micinfo','ssh_path','scp_path','tar_path') -and $c.PSObject.Properties['system_dependencies'] -and $c.system_dependencies -eq $true)
            $value=if ($externalIdentity) { [Environment]::ExpandEnvironmentVariables([string]$c.$field) } else { [string]$c.$field }
            $c.$field=Resolve-PhiLocalPath $Root $value -Contained:($portable -and !$externalIdentity -and !$systemTool)
        }
    }
    if ($portable) {
        foreach ($field in @('project_dir','phase3_kit','data_dir','key_path','micinfo','ssh_path','scp_path','tar_path','known_hosts')) {
            if (!$c.PSObject.Properties[$field]) { throw ('Portable connection is missing '+$field) }
        }
    }
    return $c
}
function Read-PhiBaseline($Connection) {
    $state=Read-JsonFile (Join-Path $Connection.phase3_kit 'artifacts/last-build.json')
    if ($state.PSObject.Properties['runtime_archive']) {
        $portable=($Connection.PSObject.Properties['portable'] -and $Connection.portable -eq $true)
        $state.runtime_archive=Resolve-PhiLocalPath $Connection.phase3_kit $state.runtime_archive -Contained:$portable
    }
    return $state
}
function Get-PhiTool($Connection,[string]$Name) {
    $field=$Name+'_path'
    if ($Connection.PSObject.Properties[$field]) {
        if (!(Test-Path -LiteralPath $Connection.$field -PathType Leaf)) { throw ('Bundled tool is missing: '+$Name) }
        return $Connection.$field
    }
    return (Get-Command ($Name+'.exe') -ErrorAction Stop).Source
}
function Get-PhiSshOptions($Connection) {
    $options=@('-o','StrictHostKeyChecking=yes','-o','BatchMode=yes','-o','IdentitiesOnly=yes','-o','ConnectTimeout=10','-o','ServerAliveInterval=5','-o','ServerAliveCountMax=3','-i',$Connection.key_path)
    if ($Connection.PSObject.Properties['known_hosts']) {
        if (!(Test-Path -LiteralPath $Connection.known_hosts -PathType Leaf)) { throw 'Bundled SSH host trust is missing.' }
        # SSH parses option values itself; quote the filename as well as argv.
        $trust=$Connection.known_hosts.Replace('\','/')
        if ($trust.Contains('"')) { throw 'Invalid SSH trust path.' }
        $options=@('-F','NUL','-o',('UserKnownHostsFile="'+$trust+'"'),'-o','GlobalKnownHostsFile=NUL')+$options
    }
    return $options
}
