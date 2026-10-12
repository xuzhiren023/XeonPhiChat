. (Join-Path $PSScriptRoot 'CapturedProcess.ps1')

if (!('PhiRecovery.Files' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'Files.cs') }

function Write-Utf8([string]$Path,[string]$Text) {
    [IO.File]::WriteAllText($Path,$Text.Replace("`r`n","`n"),(New-Object Text.UTF8Encoding($false)))
}

function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }

function Save-Json([string]$Path,$Value) {
    Write-Utf8 ($Path+'.new') ($Value | ConvertTo-Json -Depth 18)
    Move-Item -LiteralPath ($Path+'.new') -Destination $Path -Force
}

function Join-NativeArguments([string[]]$Values) {
    $parts=foreach ($value in $Values) {
        '"'+[regex]::Replace([regex]::Replace($value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'
    }
    return ($parts -join ' ')
}

function New-Directory([string]$Path) { $null=New-Item -ItemType Directory -Path $Path -Force }

function Resolve-Absolute([string]$Path) { return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar) }

function Test-Within([string]$Child,[string]$Parent) {
    $c=Resolve-Absolute $Child; $p=(Resolve-Absolute $Parent)+[IO.Path]::DirectorySeparatorChar
    return $c.StartsWith($p,[StringComparison]::OrdinalIgnoreCase)
}

function Get-Relative([string]$Path,[string]$Root) {
    if (!(Test-Within $Path $Root)) { throw "Path must be inside $Root : $Path" }
    return (Resolve-Absolute $Path).Substring((Resolve-Absolute $Root).Length+1).Replace('\','/')
}

function Join-Safe([string]$Root,[string]$Relative) {
    if (!$Relative -or $Relative -match '(^[/\\]|[:\x00-\x1f]|(^|[/\\])\.{1,2}([/\\]|$))') { throw 'Unsafe relative path.' }
    $p=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (!(Test-Within $p $Root)) { throw 'Path escapes its root.' }
    return $p
}

function Get-TreeFiles([string]$Root,[string[]]$Skip=@()) {
    $queue=New-Object 'Collections.Generic.Queue[string]'; $queue.Enqueue((Resolve-Absolute $Root))
    while ($queue.Count) {
        $dir=$queue.Dequeue()
        if ((Get-Item -LiteralPath $dir -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point is not copied: $dir" }
        foreach ($item in @(Get-ChildItem -LiteralPath $dir -Force)) {
            $relative=Get-Relative $item.FullName $Root
            $omit=$false
            foreach ($pattern in $Skip) { if ($relative -like $pattern) { $omit=$true; break } }
            if ($omit) { continue }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point is not copied: $($item.FullName)" }
            if ($item.PSIsContainer) { $queue.Enqueue($item.FullName) } else { $item }
        }
    }
}

function Assert-Windows {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Run this command in Windows PowerShell on the MPSS laptop.' }
}

function Assert-PrivateAddress([string]$Address) {
    $ip=$null
    if (![Net.IPAddress]::TryParse($Address,[ref]$ip) -or $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Configure a private IPv4 card address.' }
    $b=$ip.GetAddressBytes()
    if (!($b[0] -eq 10 -or ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) -or ($b[0] -eq 192 -and $b[1] -eq 168))) { throw 'Card address must be private IPv4; public routing is unsupported.' }
}

function Get-MicState([string]$Text) {
    $lines=@($Text -split "`r?`n" | Where-Object { $_ -match '^\s*mic0\s*:' })
    if ($lines.Count -ne 1 -or $Text -match '(?m)^\s*mic[1-9][0-9]*\s*:') { throw 'Ambiguous micctrl output; expected mic0 only.' }
    $m=[regex]::Match($lines[0],'(?i)^\s*mic0\s*:\s*(?:state\s*[:=]\s*)?(online|ready|booting)\b')
    if (!$m.Success) { throw "Card state needs operator attention; no reset attempted: $($lines[0])" }
    return $m.Groups[1].Value.ToLowerInvariant()
}

function Ensure-Online([scriptblock]$ReadStatus,[scriptblock]$Boot,[scriptblock]$Wait,[int]$Attempts=60) {
    $booted=$false
    for ($n=0; $n -lt $Attempts; $n++) {
        $state=Get-MicState (& $ReadStatus)
        if ($state -eq 'online') { return }
        if ($state -eq 'ready' -and !$booted) { & $Boot; $booted=$true }
        Write-Host "WAIT: mic0 $state ($($n+1)/$Attempts)"
        & $Wait
    }
    throw 'Timed out waiting for mic0 online. No reset or boot configuration change attempted.'
}