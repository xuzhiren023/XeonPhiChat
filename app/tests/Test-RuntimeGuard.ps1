# Host-only: real archive extraction/ELF parsing with mocked card transport.
param([Parameter(Mandatory=$true)][string]$Scratch)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'lib/ChatCore.ps1')
. (Join-Path $root 'lib/RuntimeGuard.ps1')
function Assert($Ok,$Message) { if (!$Ok) { throw $Message } }
$null=New-Item -ItemType Directory -Path $Scratch -Force
$script:cfg=[pscustomobject]@{source_commit=('a'*40)}
$script:sshOptions=@();$script:scpMode=@();$script:scp='fixture-scp';$script:target='fixture'
$script:present=$false;$script:corrupt=$false;$script:sent='';$script:copies=0
$tar=(Get-Command tar).Source
$script:connection=[pscustomobject]@{tar_path=$tar}
function Get-Command { param($Name,$ErrorAction); if ($Name -eq 'tar.exe') { return [pscustomobject]@{Source=$tar} };throw 'unexpected tool' }
function Set-JobStatus { param($Message) }
function Invoke-Card { param($Command);if ($Command.StartsWith('if test')) { if ($script:present) {return $script:cfg.source_commit};return '' };if ($Command.StartsWith('cp ')) {$script:copies++}; return '' }
function Send-CardFiles { param($Local,$Remote);$script:sent=$Local[0] }
function Invoke-JobProcess {
 param($Exe,$Arguments,$Seconds)
 if ($Exe -eq 'fixture-scp') {
  Copy-Item -LiteralPath $script:sent -Destination $Arguments[-1]
  if ($script:corrupt) {[IO.File]::WriteAllText($Arguments[-1],'corrupt')}
  return ''
 }
 $result=(& $Exe @Arguments | Out-String)
 if ($LASTEXITCODE -ne 0) {throw 'archive extraction failed'}
 return $result
}
$source=Join-Path $Scratch 'source';$null=New-Item -ItemType Directory -Path $source
$bytes=New-Object byte[] 64
$bytes[0]=127;$bytes[1]=69;$bytes[2]=76;$bytes[3]=70;$bytes[4]=2;$bytes[5]=1;$bytes[18]=181
$archive=Join-Path $Scratch 'runtime.tar'
$baseline=[pscustomobject]@{remote_base='/root/knc-phase3-run-old';runtime_archive=$archive}
foreach ($mode in @('restore','corrupt','wrong-elf','missing','present')) {
 $script:job=Join-Path $Scratch $mode;$null=New-Item -ItemType Directory -Path $script:job
 $script:present=($mode -eq 'present');$script:corrupt=($mode -eq 'corrupt')
 $bytes[18]=if ($mode -eq 'wrong-elf') {62} else {181}
 [IO.File]::WriteAllBytes((Join-Path $source 'guard'),$bytes)
 & $tar -cf $archive -C $source guard
 if ($mode -eq 'missing') {Remove-Item -LiteralPath $archive}
 $failed=$false
 try { Install-RuntimeGuard $baseline '/root/knc-phase3-run-modern142-fixture' } catch {$failed=$true;Write-Host ($mode+': '+$_.Exception.Message)}
 Assert ($failed -eq ($mode -in @('corrupt','wrong-elf','missing'))) ('wrong outcome '+$mode)
}
Assert ($script:copies -eq 1) 'existing guard not reused'
Write-Host 'PASS: real saved-guard extraction, K1OM validation, transfer hash, missing archive failure and existing guard reuse; card transport mocked.'
