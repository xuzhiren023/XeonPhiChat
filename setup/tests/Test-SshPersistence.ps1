#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'recovery/SshPersistence.ps1')
$script:checks=0
function Check([bool]$Value,[string]$Message) { $script:checks++; if (!$Value) { throw "FAIL: $Message" } }
function Reject([scriptblock]$Action,[string]$Message) { $caught=$false; try { & $Action } catch { $caught=$true }; Check $caught $Message }
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('phi-ssh-test-'+[Guid]::NewGuid().ToString('N'))
New-Directory $tmp
try {
    # OpenSSH key operations are real. Only Windows ACL APIs are replaced.
    function Protect-IdentityDirectory([string]$Path) { }
    function Protect-IdentityFile([string]$Path) { }
    function Get-RepairAcl([string]$Path) { 'fixture-acl' }
    function Set-RepairAcl([string]$Path,[string]$Sddl) { }
    $keygen=(Get-Command ssh-keygen -ErrorAction Stop).Source
    $keyPath=Join-Path $tmp 'host_key'
    $null=Invoke-CheckedCapture -FilePath $keygen -Arguments (Join-NativeArguments @('-q','-t','ed25519','-N','','-f',$keyPath)) -ReportPrefix (Join-Path $tmp 'keygen') -Quiet
    $key=Get-PublicKey (Read-SmallText ($keyPath+'.pub'))
    $null=Invoke-CheckedCapture -FilePath $keygen -Arguments (Join-NativeArguments @('-l','-E','sha256','-f',($keyPath+'.pub'))) -ReportPrefix (Join-Path $tmp 'fingerprint') -Quiet
    Check ((Read-SmallText (Join-Path $tmp 'fingerprint.stdout.txt')).Contains($key.fingerprint)) 'fingerprint agrees with real OpenSSH'
    Reject { Get-PublicKey ('ssh-rsa '+$key.blob) } 'algorithm/blob mismatch rejected'
    Reject { Get-PublicKey ('ssh-ed25519 !!!') } 'invalid key rejected'
    $merged=Merge-AuthorizedKey "# keep existing entries`nssh-rsa AAAAdummy other`n" $key
    Check ($merged.Contains('ssh-rsa AAAAdummy other')) 'existing boot authorizations preserved'
    Check ((Merge-AuthorizedKey $merged $key) -ceq $merged) 'login authorization merge is idempotent'
    Reject { Merge-AuthorizedKey ('command="restricted" '+$key.public) $key } 'existing authorization restrictions cannot be bypassed'
    Check ((Add-Ed25519HostConfig "#HostKey old`nPermitRootLogin prohibit-password`n") -ceq "#HostKey old`nPermitRootLogin prohibit-password`n") 'default host key paths need no sshd change'
    $config=Add-Ed25519HostConfig "HostKey /etc/ssh/ssh_host_rsa_key`nMatch User guest`n PasswordAuthentication no`n"
    Check ($config.StartsWith("# Phi Chat persistent server identity`nHostKey /etc/ssh/ssh_host_ed25519_key`n")) 'explicit host key is added globally before Match'
    Check ($config.Contains('HostKey /etc/ssh/ssh_host_rsa_key')) 'other host key configuration retained'
    foreach ($blocked in @('Include /etc/ssh/conf.d/*','PermitRootLogin no','PubkeyAuthentication no','AuthorizedKeysFile /custom/keys')) { Reject { Add-Ed25519HostConfig $blocked } 'unsupported SSH policy is not weakened'
    }
    $hostText="# header`n192.168.1.100,keep.example ssh-rsa AAAA old`n10.0.0.5 ssh-rsa BBBB other`n"
    $newHosts=Set-CardKnownHostsText $hostText '192.168.1.100' $key
    Check ($newHosts.Contains('keep.example ssh-rsa AAAA old')) 'shared host aliases retained'
    Check ($newHosts.Contains('10.0.0.5 ssh-rsa BBBB other')) 'other hosts retained'
    Check (!$newHosts.Contains('192.168.1.100,keep.example')) 'only old card alias removed'
    Check ((Set-CardKnownHostsText $newHosts '192.168.1.100' $key) -ceq $newHosts) 'verified trust update is idempotent'
    $hashed=Join-Path $tmp 'known_hosts'; Write-Utf8 $hashed ('192.168.1.100 '+$key.public+"`n")
    $null=Invoke-CheckedCapture -FilePath $keygen -Arguments (Join-NativeArguments @('-H','-f',$hashed)) -ReportPrefix (Join-Path $tmp 'hash-host') -Quiet
    $unhashed=Set-CardKnownHostsText (Read-SmallText $hashed) '192.168.1.100' $key
    Check (!$unhashed.Contains('|1|')) 'actual OpenSSH hashed card entry recognized'
    foreach ($marked in @('@revoked 192.168.1.100','@revoked *','@cert-authority 192.168.1.*')) { Reject { Set-CardKnownHostsText ($marked+' '+$key.public) '192.168.1.100' $key } 'revocation/CA markers are not silently overridden' }

    function New-Fixture {
        $base=Join-Path $tmp ([Guid]::NewGuid().ToString('N'))
        $recovery=Join-Path $base 'PhiChat/setup-state'; $mpss=Join-Path $base 'Program Files/Intel/MPSS'
        $identity=Join-Path $recovery 'data/ssh-identity'; $planDir=Join-Path $recovery 'data/ssh-repair/plan'
        foreach ($dir in @($identity,$planDir,(Join-Path $recovery 'data/app/config'),(Join-Path $mpss 'filesystem/common/etc/ssh'),(Join-Path $mpss 'filesystem/common/root/.ssh'),(Join-Path $mpss 'filesystem/mic0'),(Join-Path $mpss 'bin'))) { New-Directory $dir }
        Save-Json (Join-Path $recovery 'data/settings.yaml') ([pscustomobject]@{mpss_dir=$mpss})
        Save-Json (Join-Path $recovery 'data/app/config/connection.yaml') ([pscustomobject]@{card_address='192.168.1.100'})
        foreach ($name in @('mic0.xml','global.xml','bin/micctrl.exe','bin/micinfo.exe')) { Write-Utf8 (Join-Path $mpss $name) 'fixture-only' }
        Write-Utf8 (Join-Path $mpss 'filesystem/mic0.image') 'original boot image'
        Write-Utf8 (Join-Path $mpss 'filesystem/common.filelist') "dir /etc 755 0 0`ndir /etc/ssh 755 0 0`ndir /root 700 0 0`ndir /root/.ssh 700 0 0`nfile /root/.ssh/authorized_keys root/.ssh/authorized_keys 600 0 0`nfile /etc/ssh/sshd_config etc/ssh/sshd_config 600 0 0`n"
        Write-Utf8 (Join-Path $mpss 'filesystem/common/root/.ssh/authorized_keys') "# original users`nssh-rsa AAAAdummy other`n"
        Write-Utf8 (Join-Path $mpss 'filesystem/common/etc/ssh/sshd_config') "HostKey /etc/ssh/ssh_host_rsa_key`nPermitRootLogin yes`n"
        Write-Utf8 (Join-Path $mpss 'filesystem/mic0.filelist') "# preserve this comment`nfile /etc/hostname etc/hostname 644 0 0`n"
        Copy-Item -LiteralPath $keyPath -Destination (Join-Path $identity 'ssh_host_ed25519_key')
        $plan=New-SshPersistencePlan $recovery $planDir $identity $key.public $key.public 'serial-fixture'
        return [pscustomobject]@{recovery=$recovery;mpss=$mpss;dir=$planDir;plan=$plan}
    }
    $f=New-Fixture
    $listBefore=Read-SmallText (Join-Path $f.mpss 'filesystem/mic0.filelist')
    Check (!(Test-Path -LiteralPath (Join-Path $f.mpss 'filesystem/mic0/phi-chat-identity'))) 'prepare writes no MPSS payload'
    $candidate=Read-SmallText (Join-Path $f.dir 'payload/mic0.filelist')
    Check ($candidate.Contains('file /etc/hostname etc/hostname 644 0 0')) 'unrelated boot entry preserved'
    Check ($candidate.Contains('file /etc/ssh/ssh_host_ed25519_key phi-chat-identity/ssh_host_ed25519_key 600 0 0')) 'persistent host private key has root-only mode'
    Check ((Read-SmallText (Join-Path $f.dir 'payload/authorized_keys')).Contains('ssh-rsa AAAAdummy other')) 'common authorization retained in per-card overlay'
    $journal=Apply-SshPersistencePlan $f.dir { param($p) Write-Utf8 $p.images[0] ('new boot image '+$p.marker) }
    Check ($journal.state -ceq 'image-generated') 'successful generation remains unverified, not accepted'
    Check ((Read-SmallText (Join-Path $f.mpss 'filesystem/mic0/phi-chat-identity/receipt.txt')).Trim() -ceq $f.plan.marker) 'boot proof marker staged'
    Check (!(Test-Path -LiteralPath (Join-Path $f.recovery 'data/ssh-identity/verified.json'))) 'generation cannot fabricate reboot verification'
    Reject { Apply-SshPersistencePlan $f.dir {} } 'an attempted plan cannot be applied twice'
    Assert-IdentityInputs $journal.after
    Restore-IdentityTargets $journal $f.dir
    Check ((Read-SmallText (Join-Path $f.mpss 'filesystem/mic0.filelist')) -ceq $listBefore) 'rollback restores original filelist bytes'
    Check ((Read-SmallText $f.plan.images[0]) -ceq 'original boot image') 'rollback restores original image'
    Check (!(Test-Path -LiteralPath (Join-Path $f.mpss 'filesystem/mic0/phi-chat-identity/ssh_host_ed25519_key'))) 'rollback removes only newly created payload file'
    foreach ($failure in @('generation-error','ignored-overlay','xml-mutation')) {
        $f=New-Fixture
        $callback=if ($failure -ceq 'generation-error') { {param($p) Write-Utf8 $p.images[0] 'partial image'; throw 'fixture generation failed'} }
                  elseif ($failure -ceq 'ignored-overlay') { {param($p)} }
                  else { {param($p) Write-Utf8 $p.images[0] 'changed'; Write-Utf8 (Join-Path $p.mpss 'mic0.xml') 'unexpected config mutation'} }
        Reject { Apply-SshPersistencePlan $f.dir $callback } $failure
        Check ((Read-SmallText $f.plan.images[0]) -ceq 'original boot image') 'failed generation rolls back image'
        Check ((Read-SmallText (Join-Path $f.mpss 'mic0.xml')) -ceq 'fixture-only') 'failed generation preserves boot XML'
        Check ((Read-Json (Join-Path $f.dir 'journal.json')).state -ceq 'rolled-back') 'failure recorded without acceptance'
    }
    $f=New-Fixture; Write-Utf8 (Join-Path $f.mpss 'filesystem/mic0.filelist') '# operator edit'
    Reject { Apply-SshPersistencePlan $f.dir { throw 'must not run' } } 'changed input stops before apply'
    Check (!(Test-Path -LiteralPath (Join-Path $f.dir 'journal.json'))) 'changed input stops before backup/apply journal'
    $f=New-Fixture; Write-Utf8 (Join-Path $f.dir 'payload/ssh_host_ed25519_key') 'damaged'
    Reject { Apply-SshPersistencePlan $f.dir { throw 'must not run' } } 'damaged private payload stops before apply'
    Check ((Read-SmallText $f.plan.images[0]) -ceq 'original boot image') 'damaged payload leaves image unchanged'
    $f=New-Fixture; $j=Apply-SshPersistencePlan $f.dir {param($p) Write-Utf8 $p.images[0] 'new image'}
    Write-Utf8 (Join-Safe $f.dir $j.entries[0].backup) 'bad backup'
    Reject { Restore-IdentityTargets $j $f.dir } 'damaged backup blocks rollback before writes'
    Check ((Read-SmallText $f.plan.images[0]) -ceq 'new image') 'blocked rollback leaves current image intact'

    $script:reads=0; $script:resets=0; $script:boots=0
    $states=@('mic0: online','mic0: online','mic0: resetting','mic0: ready','mic0: booting','mic0: online')
    Restart-MicIdentity 'online' -ReadStatus { $s=$states[$script:reads]; $script:reads++; $s } -Reset {$script:resets++} -Boot {$script:boots++} -Wait {} -Attempts 8
    Check ($script:resets -eq 1 -and $script:boots -eq 1 -and $script:reads -eq 6) 'restart waits for actual transition, not stale online status'
    $script:resets=0; $script:boots=0
    Reject { Restart-MicIdentity 'online' -ReadStatus {'mic0: online'} -Reset {$script:resets++} -Boot {$script:boots++} -Wait {} -Attempts 2 } 'unobserved reboot times out'
    Check ($script:resets -eq 1 -and $script:boots -eq 0) 'timeout never loops resets'
    Write-Host "PASS: $script:checks SSH persistence checks; no card, MPSS or system SSH configuration changes."
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
