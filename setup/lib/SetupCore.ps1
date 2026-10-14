#Requires -Version 5.1
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../recovery/SshPersistence.ps1')

function Get-PhiVersion([string]$Root) { return [IO.File]::ReadAllText((Join-Path $Root 'VERSION')).Trim() }
function New-PhiSetupDiagnostics([string]$Id='') {
    if (!$Id) { $Id=[Guid]::NewGuid().ToString('N') }
    if ($Id -cnotmatch '^[a-f0-9]{32}$') { throw 'Invalid setup diagnostic ID.' }
    # Preflight can fail before an installation exists. Keep its diagnostics
    # outside Destination so logging cannot turn an empty install into a conflict.
    $path=Join-Path $env:LOCALAPPDATA ('PhiChat/SetupLogs/'+$Id)
    Assert-RegularPath $path
    New-Directory $path
    return $path
}
function Write-PhiSetupFailure([string]$Directory,[Management.Automation.ErrorRecord]$Failure) {
    Save-Json (Join-Path $Directory ('error-'+$PID+'.json')) ([pscustomobject]@{
        message=$Failure.Exception.Message;exception_type=$Failure.Exception.GetType().FullName;
        position=$Failure.InvocationInfo.PositionMessage;script_stack=$Failure.ScriptStackTrace;
        process_id=$PID;created_utc=[DateTime]::UtcNow.ToString('o')})
}
function Get-PhiElevatedFailure([string]$Directory,[int]$ProcessId) {
    $path=Join-Path $Directory ('error-'+$ProcessId+'.json')
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try { return [string](Read-Json $path).message } catch {}
    }
    return 'The elevated process did not report a result. Review its console; use the same Windows account when accepting UAC.'
}
function Get-PhiSetupRun([string]$Destination) {
    $path=Join-Path $Destination ('data/setup/run-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8))
    New-Directory $path
    return $path
}
function Invoke-SetupProcess([string]$Exe,[string[]]$Arguments,[string]$Run,[int]$Timeout=15000) {
    $prefix=Join-Path $Run ([Guid]::NewGuid().ToString('N'))
    $null=Invoke-CheckedCapture -FilePath $Exe -Arguments (Join-NativeArguments $Arguments) -ReportPrefix $prefix -Quiet -TimeoutMilliseconds $Timeout
    return [IO.File]::ReadAllText($prefix+'.stdout.txt')
}
function Assert-PhiAsset([string]$Path,$Asset) {
    Assert-RegularPath $Path
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw ('Required release asset is missing: '+$Asset.file+'. Use the complete installer ZIP or supply -AssetsDirectory.') }
    if ((Get-Item -LiteralPath $Path).Length -ne $Asset.bytes -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $Asset.sha256) {
        throw ('Release asset failed SHA-256 verification: '+$Asset.file)
    }
}
function Read-PhiAssetManifest([string]$Root) {
    $manifest=Read-Json (Join-Path $Root 'assets/runtime-manifest.json')
    if ($manifest.schema_version -ne 1 -or $manifest.version -cne (Get-PhiVersion $Root)) { throw 'Unsupported release asset manifest.' }
    $names=@{}
    foreach ($asset in $manifest.assets) {
        if ($asset.file -notmatch '^(?:(?:runtime-(?:3120A|7120P)|baseline-runtime|prime-7120P)\.tar|mmproj-Step3-VL-10b-61e9799-Q6_K\.gguf)$' -or $asset.sha256 -notmatch '^[a-f0-9]{64}$' -or $asset.bytes -lt 1024 -or $names.ContainsKey($asset.file)) { throw 'Invalid release asset identity.' }
        $kind=if ($asset.file.EndsWith('.gguf')) {'vision-projector'} elseif ($asset.file -ceq 'baseline-runtime.tar') {'guard-backup'} elseif ($asset.file -ceq 'prime-7120P.tar') {'priming'} else {'modern'}
        if ($asset.kind -cne $kind) {throw 'Release asset kind differs from its file identity.'}
        if ($kind -ceq 'vision-projector' -and ($asset.model_id -cne 'step3-vl-10b-q5_k_m-projector' -or $asset.model_path -cne ('models/uniform-q5-k/'+$asset.file))) {throw 'Invalid bundled projector destination.'}
        $names[$asset.file]=$true
    }
    if ($names.Count -ne 5) { throw 'The release must contain both hardware runtimes, the watchdog backup, the priming runtime and the Step3 vision component.' }
    return $manifest
}
function Get-PhiAssets([string]$Root,[string]$AssetsDirectory) {
    if (!$AssetsDirectory) { $AssetsDirectory=Join-Path $Root 'assets/payloads' }
    $manifest=Read-PhiAssetManifest $Root
    foreach ($asset in $manifest.assets) { Assert-PhiAsset (Join-Safe $AssetsDirectory $asset.file) $asset }
    return $manifest
}
function Copy-PhiApplication([string]$Root,[string]$Destination) {
    $Root=Resolve-Absolute $Root; $Destination=Resolve-Absolute $Destination
    if ($Root -ceq $Destination -or (Test-Within $Destination $Root) -or (Test-Within $Root $Destination)) { throw 'Choose an installation folder separate from the download/source folder.' }
    Assert-RegularPath $Destination
    if (Test-Path -LiteralPath $Destination) {
        if (@(Get-ChildItem -LiteralPath $Destination -Force).Count) {
            $receiptPath=Join-Path $Destination 'installation.json'
            if (!(Test-Path -LiteralPath $receiptPath)) { throw 'The destination contains unrelated files. Choose an empty folder.' }
            $receipt=Read-Json $receiptPath
            if ($receipt.version -cne (Get-PhiVersion $Root) -or $receipt.product -cne 'PhiChat') { throw 'Use a new folder for this app version. Existing installation preserved.' }
            foreach ($file in $receipt.source_files) {
                $installed=Join-Safe $Destination $file.path
                $incoming=Join-Safe $Root $file.path
                if (!(Test-Path -LiteralPath $installed) -or (Get-FileHash -LiteralPath $installed).Hash.ToLowerInvariant() -cne $file.sha256 -or (Get-FileHash -LiteralPath $incoming).Hash.ToLowerInvariant() -cne $file.sha256) { throw 'Installed or source code changed since setup. Preserve it and choose a new folder.' }
            }
            return $receipt
        }
    }
    New-Directory $Destination
    $files=New-Object Collections.ArrayList
    $roots=@('app','setup','docs','licenses')
    $sources=@(foreach ($name in $roots) { Get-TreeFiles (Join-Path $Root $name) @('tests/*','__pycache__/*') })
    $sources+=@(Get-Item -LiteralPath (Join-Path $Root 'VERSION'),(Join-Path $Root 'Start.cmd'),(Join-Path $Root 'Start.ps1'),(Join-Path $Root 'Setup.cmd'),(Join-Path $Root 'Setup.ps1'),(Join-Path $Root 'Add-Models.cmd'),(Join-Path $Root 'README.md'),(Join-Path $Root 'LICENSES.md'))
    $sources+=@(Get-TreeFiles (Join-Path $Root 'assets') @('payloads') | Where-Object Extension -CEQ '.json')
    foreach ($source in $sources) {
        $relative=Get-Relative $source.FullName $Root
        if ($relative -match '/(data|private|jobs)/|/config/connection.yaml$') { throw 'Machine state must not appear in app source.' }
        $target=Join-Safe $Destination $relative; New-Directory (Split-Path $target -Parent)
        Copy-Item -LiteralPath $source.FullName -Destination $target
        $hash=(Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant()
        if ($hash -cne (Get-FileHash -LiteralPath $source.FullName).Hash.ToLowerInvariant()) { throw 'Application copy verification failed.' }
        $null=$files.Add([pscustomobject]@{path=$relative;sha256=$hash})
    }
    $receipt=[pscustomobject]@{schema_version=1;product='PhiChat';version=(Get-PhiVersion $Root);status='copied';source_files=@($files);created_utc=[DateTime]::UtcNow.ToString('o')}
    Save-Json (Join-Path $Destination 'installation.json') $receipt
    return $receipt
}
function Install-PhiAssets([string]$Root,[string]$AssetsDirectory,[string]$Destination) {
    if (!$AssetsDirectory) { $AssetsDirectory=Join-Path $Root 'assets/payloads' }
    $manifest=Get-PhiAssets $Root $AssetsDirectory
    $app=Join-Path $Destination 'app'
    foreach ($asset in $manifest.assets) {
        if ($asset.kind -ceq 'vision-projector') {
            $target=Join-Safe $app $asset.model_path
            New-Directory (Split-Path $target -Parent)
            if (Test-Path -LiteralPath $target) { Assert-PhiAsset $target $asset }
            else {
                $part=$target+'.'+[Guid]::NewGuid().ToString('N')+'.part'
                try {
                    Copy-Item -LiteralPath (Join-Safe $AssetsDirectory $asset.file) -Destination $part
                    Assert-PhiAsset $part $asset
                    [IO.File]::Move($part,$target)
                } finally { if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part } }
            }
            # Setup admits this dependency once. Load and card transfer reuse it.
            $file=Get-Item -LiteralPath $target
            New-Directory (Join-Path $app 'data')
            Save-Json (Join-Path $app ('data/model-'+$asset.model_id+'.json')) ([pscustomobject]@{
                path=$file.FullName;bytes=$file.Length;modified_ticks=$file.LastWriteTimeUtc.Ticks;sha256=$asset.sha256})
            continue
        }
        $relative=if ($asset.kind -ceq 'guard-backup') { 'dependencies/phase3/runtime.tar' } elseif ($asset.kind -ceq 'priming') { 'data/priming-runtime/payload-'+$asset.sha256+'/'+$asset.file } else { 'data/modern-runtime/payload-'+$asset.sha256+'/'+$asset.file }
        $target=Join-Safe $app $relative
        New-Directory (Split-Path $target -Parent)
        Copy-Item -LiteralPath (Join-Safe $AssetsDirectory $asset.file) -Destination $target -Force
        Assert-PhiAsset $target $asset
    }
    # This receipt is only a bootstrap input, never a fabricated native PASS.
    New-Directory (Join-Path $app 'dependencies/phase3/artifacts')
    Save-Json (Join-Path $app 'dependencies/phase3/artifacts/last-build.json') ([pscustomobject]@{
        schema_version=1;kind='watchdog-bootstrap-only';native_acceptance=$false;
        source_commit='03a8b80c7d502797325788f604248dd4aabdf5ef';remote_base='/root/knc-phase3-run-bootstrap';runtime_archive='runtime.tar'})
}
function New-PhiClientIdentity([string]$Destination,[string]$Run) {
    $private=Join-Path $Destination 'app/private'; New-Directory $private; Protect-IdentityDirectory $private
    $keygen=(Get-Command ssh-keygen.exe -ErrorAction Stop).Source
    foreach ($name in @('id_ed25519','ssh_host_ed25519_key')) {
        $path=Join-Path $private $name
        if (!(Test-Path -LiteralPath $path)) {
            if (Test-Path -LiteralPath ($path+'.pub')) { throw 'Orphan public identity found; existing identity is preserved.' }
            $null=Invoke-SetupProcess $keygen @('-q','-t','ed25519','-N','','-C','phi-chat-mic0','-f',$path) $Run
        }
        Protect-IdentityFile $path
        $key=Get-PublicKey (Invoke-SetupProcess $keygen @('-y','-P','','-f',$path) $Run)
        if ((Get-PublicKey (Read-SmallText ($path+'.pub'))).public -cne $key.public) { throw 'Saved SSH key pair disagrees. No identity was rotated.' }
    }
    return [pscustomobject]@{client=(Get-PublicKey (Read-SmallText (Join-Path $private 'id_ed25519.pub')));server=(Get-PublicKey (Read-SmallText (Join-Path $private 'ssh_host_ed25519_key.pub')));directory=$private}
}
function Write-PhiConnection([string]$Destination,[string]$Mpss,[string]$Address) {
    Assert-PrivateAddress $Address
    $connection=[pscustomobject]@{schema_version=3;portable=$true;system_dependencies=$true;project_dir='.';
        phase3_kit='dependencies/phase3';data_dir='data';card_address=$Address;key_path='private/id_ed25519';
        known_hosts='private/known_hosts';micinfo=(Join-Path $Mpss 'bin/MicInfo.exe');
        ssh_path=(Get-Command ssh.exe).Source;scp_path=(Get-Command scp.exe).Source;tar_path=(Get-Command tar.exe).Source}
    New-Directory (Join-Path $Destination 'app/data/jobs')
    Save-Json (Join-Path $Destination 'app/config/connection.yaml') $connection
}
function Invoke-PhiSetupJob([string]$Destination,[string]$Action,[string]$Model='', [string]$Serial='') {
    $app=Join-Path $Destination 'app'
    . (Join-Path $app 'lib/BackendClient.ps1')
    $connection=Read-PhiConnection $app
    $request=[pscustomobject]@{action=$Action;owner_pid=$PID;batch=0}
    # Setup stages the first model. The chat window owns its resident worker.
    if ($Action -ceq 'Load') {$request | Add-Member prime_model $false}
    if ($Model) { $request | Add-Member model $Model; $request | Add-Member connected_serial $Serial }
    $job=Start-PhiBackendJob $app $connection.data_dir $request
    try {
        $last=''
        while (!$job.process.WaitForExit(1000)) {
            $path=Join-Path $job.directory 'status.json'
            if (Test-Path -LiteralPath $path) {
                try { $status=Read-JsonFile $path; if ($status.message -cne $last) { Write-Host $status.message; $last=$status.message } } catch {}
            }
        }
        $status=Read-JsonFile (Join-Path $job.directory 'status.json')
        if ($job.process.ExitCode -ne 0 -or $status.state -cne 'done') { throw ('Setup '+$Action+' failed: '+$status.message+'. Evidence: '+$job.directory) }
        return $status
    } finally { $job.process.Dispose() }
}
function Get-PhiModelPackSelection([string]$Root,[string]$Pack,[string[]]$ModelIds=@()) {
    $manifest=Read-Json (Join-Path $Root 'assets/optimized-models.json')
    if ($manifest.schema_version -ne 1 -or @($manifest.models).Count -lt 1) { throw 'Invalid local model manifest.' }
    $ids=@{}; $paths=@{}
    foreach ($model in @($manifest.models)) {
        if ($model.id -notmatch '^[a-z0-9][a-z0-9_.-]+$' -or
            $model.path -notmatch '^models/uniform-q5-k/[A-Za-z0-9_.-]+\.gguf$' -or
            $model.sha256 -notmatch '^[a-f0-9]{64}$' -or $model.bytes -lt 1 -or
            $ids.ContainsKey($model.id) -or $paths.ContainsKey($model.path)) { throw 'Invalid or duplicate pinned model identity.' }
        $ids[$model.id]=$true; $paths[$model.path]=$true
    }
    if ($ModelIds.Count) {
        foreach ($id in $ModelIds) { if (!$ids.ContainsKey($id)) { throw ('Unknown pinned model ID: '+$id) } }
        $selected=@($manifest.models | Where-Object { $_.id -cin $ModelIds })
    } else {
        # A new single-model pack need not include earlier multi-gigabyte models.
        # Only identities pinned by this app are eligible; pack-supplied metadata
        # never authorizes a new hash or a new runtime.
        $selected=@($manifest.models | Where-Object { Test-Path -LiteralPath (Join-Safe $Pack $_.path) -PathType Leaf })
    }
    if (!$selected.Count) { throw 'No recognized model files found. Select the extracted folder containing models/uniform-q5-k.' }
    foreach ($model in $selected) {
        $source=Join-Safe $Pack $model.path
        Assert-PhiAsset $source ([pscustomobject]@{file=$model.path;bytes=$model.bytes;sha256=$model.sha256})
    }
    return $selected
}
function Import-PhiOptimizedModels([string]$Root,[string]$Destination,[string]$Pack,[string[]]$ModelIds=@()) {
    # Folder import avoids extracting arbitrary archives into the installation.
    $selected=@(Get-PhiModelPackSelection $Root $Pack $ModelIds)
    # Check all existing destinations before writing any model from the pack.
    foreach ($model in $selected) {
        $target=Join-Safe (Join-Path $Destination 'app') $model.path
        Assert-RegularPath $target
        if (Test-Path -LiteralPath $target) { Assert-PhiAsset $target ([pscustomobject]@{file=$model.path;bytes=$model.bytes;sha256=$model.sha256}) }
    }
    foreach ($model in $selected) {
        $source=Join-Safe $Pack $model.path; $target=Join-Safe (Join-Path $Destination 'app') $model.path
        New-Directory (Split-Path $target -Parent)
        if (Test-Path -LiteralPath $target) {
            Assert-PhiAsset $target ([pscustomobject]@{file=$model.path;bytes=$model.bytes;sha256=$model.sha256})
            continue
        }
        $part=$target+'.'+[Guid]::NewGuid().ToString('N')+'.part'
        try {
            Copy-Item -LiteralPath $source -Destination $part
            Assert-PhiAsset $part ([pscustomobject]@{file=$model.path;bytes=$model.bytes;sha256=$model.sha256})
            [IO.File]::Move($part,$target)
        } finally { if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part } }
    }
    return [pscustomobject]@{count=$selected.Count;model_ids=@($selected | ForEach-Object id);runtime_acceptance_changed=$false;
        blocked_model_ids=@($selected | Where-Object { $_.PSObject.Properties['runtime_status'] -and $_.runtime_status -ceq 'blocked_lfm2moe' } | ForEach-Object id)}
}
function New-PhiShortcut([string]$Destination) {
    $path=Join-Path ([Environment]::GetFolderPath('Desktop')) ('Phi Chat '+(Get-PhiVersion $Destination)+'.lnk')
    $shell=New-Object -ComObject WScript.Shell
    try {
        $link=$shell.CreateShortcut($path)
        if ((Test-Path -LiteralPath $path) -and $link.WorkingDirectory -cne $Destination) { throw 'An existing shortcut with this name belongs to another installation.' }
        $link.TargetPath=(Get-Command powershell.exe).Source
        $link.Arguments=Join-NativeArguments @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-WindowStyle','Hidden','-File',(Join-Path $Destination 'Start.ps1'))
        $link.WorkingDirectory=$Destination; $link.Description='Phi Chat on Intel Xeon Phi'; $link.Save()
    } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
}
