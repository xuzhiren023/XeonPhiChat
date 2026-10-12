# Restore only the accepted watchdog, never run the old compiler or restore UI.
function Install-RuntimeGuard($Baseline,[string]$Remote) {
    $script:activity='Preparing the accepted watchdog (no compilation).'
    Set-JobStatus $script:activity
    $present=(Invoke-Card "if test -x '$($Baseline.remote_base)/guard' && test -f '$($Baseline.remote_base)/build-passed.txt'; then cat '$($Baseline.remote_base)/build-passed.txt'; fi").Trim()
    if ($present -ceq $script:cfg.source_commit) {
        $null=Invoke-Card "cp '$($Baseline.remote_base)/guard' '$Remote/guard'"
    } else {
        if (!(Test-Path -LiteralPath $Baseline.runtime_archive -PathType Leaf)) {
            throw "The card watchdog is absent and its accepted Windows backup is missing: $($Baseline.runtime_archive). Restore that runtime.tar backup; no compiler is required."
        }
        $tar=Get-PhiTool $script:connection 'tar'
        $members=(Invoke-JobProcess $tar @('-tf',$Baseline.runtime_archive) 60) -split '\r?\n'
        $guardMembers=@($members | Where-Object { $_ -ceq 'guard' -or $_ -ceq './guard' })
        if ($guardMembers.Count -ne 1) { throw 'Accepted runtime archive must contain exactly one root guard member.' }
        $dir=Join-Path $script:job 'accepted-watchdog'
        $null=New-Item -ItemType Directory -Path $dir
        $null=Invoke-JobProcess $tar @('-xf',$Baseline.runtime_archive,'-C',$dir,$guardMembers[0]) 60
        $guard=Join-Path $dir 'guard'
        $item=Get-Item -LiteralPath $guard -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -lt 20 -or $item.Length -gt 2MB) { throw 'Invalid accepted watchdog file.' }
        $bytes=[IO.File]::ReadAllBytes($guard)
        if ($bytes[0] -ne 127 -or $bytes[1] -ne 69 -or $bytes[2] -ne 76 -or $bytes[3] -ne 70 -or $bytes[4] -ne 2 -or $bytes[5] -ne 1 -or $bytes[18] -ne 181 -or $bytes[19] -ne 0) { throw 'Accepted watchdog is not ELF64 K1OM.' }
        $sha=(Get-FileHash -LiteralPath $guard -Algorithm SHA256).Hash
        Send-CardFiles @($guard) ($Remote+'/')
        $returned=Join-Path $script:job 'staged-guard'
        $null=Invoke-JobProcess $script:scp ($script:scpMode+$script:sshOptions+@(($script:target+':'+$Remote+'/guard'),$returned)) 60
        if ((Get-FileHash -LiteralPath $returned -Algorithm SHA256).Hash -cne $sha) { throw 'Watchdog transfer hash mismatch.' }
        Write-JsonFile (Join-Path $script:job 'watchdog.json') ([pscustomobject]@{source_archive=$Baseline.runtime_archive;sha256=$sha;restored=$true})
    }
    # This is a guard-source receipt, deliberately not a native build/acceptance receipt.
    $null=Invoke-Card "chmod 700 '$Remote/guard' && printf '%s\n' '$($script:cfg.source_commit)' > '$Remote/guard-source.txt'"
}
