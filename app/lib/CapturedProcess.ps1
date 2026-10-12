# Windows PowerShell 5.1 / .NET Framework 4.5+ compatible.
# Keep ownership of the native process instead of relying on Start-Process's
# returned Process object. Drain both pipes while waiting, with bounded waits.
function Invoke-CheckedCapture {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ReportPrefix,
        [string]$Arguments = '',
        [switch]$Quiet,
        [ValidateRange(1,60000)][int]$TimeoutMilliseconds = 15000
    )
    $stdoutPath = $ReportPrefix + '.stdout.txt'
    $stderrPath = $ReportPrefix + '.stderr.txt'
    $statusPath = $ReportPrefix + '.exit.json'
    foreach ($path in @($stdoutPath, $stderrPath, $statusPath)) {
        if (Test-Path -LiteralPath $path) { throw "Refusing to overwrite prior evidence: $path" }
    }
    $result = [pscustomobject]@{
        executable = $FilePath
        powershell_version = $PSVersionTable.PSVersion.ToString()
        started_at = (Get-Date).ToString('o')
        timeout_ms = $TimeoutMilliseconds
        started = $false
        timed_out = $false
        exit_code = $null
        stdout_complete = $false
        stderr_complete = $false
        process_error = ''
        stdout_file = $stdoutPath
        stderr_file = $stderrPath
    }
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = $FilePath
    $process.StartInfo.Arguments = $Arguments
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $outTask = $null
    $errTask = $null
    $stdout = ''
    $stderr = ''
    try {
        $result.started = $process.Start()
        if (!$result.started) { throw 'Native process did not start.' }
        $outTask = $process.StandardOutput.ReadToEndAsync()
        $errTask = $process.StandardError.ReadToEndAsync()
        if (!$process.WaitForExit($TimeoutMilliseconds)) {
            $result.timed_out = $true
            $process.Kill()
            if (!$process.WaitForExit(5000)) { throw 'Timed-out process did not stop after Kill.' }
        }
        # Never cast a missing exit code to zero: null must remain a failure.
        $result.exit_code = $process.ExitCode
    } catch {
        $result.process_error = $_.Exception.Message
    } finally {
        # Also stop the process if an exception interrupted capture after Start.
        try {
            if ($result.started -and !$process.HasExited) {
                $process.Kill()
                $null = $process.WaitForExit(2000)
            }
        } catch { $result.process_error += " Cleanup: $($_.Exception.Message)" }
        try {
            if ($null -ne $outTask -and $outTask.Wait(5000)) {
                $stdout = $outTask.Result
                $result.stdout_complete = $true
            }
        } catch { $result.process_error += " Stdout: $($_.Exception.Message)" }
        try {
            if ($null -ne $errTask -and $errTask.Wait(5000)) {
                $stderr = $errTask.Result
                $result.stderr_complete = $true
            }
        } catch { $result.process_error += " Stderr: $($_.Exception.Message)" }
        $process.Dispose()
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($stdoutPath, $stdout, $utf8)
        [IO.File]::WriteAllText($stderrPath, $stderr, $utf8)
        [IO.File]::WriteAllText($statusPath, ($result | ConvertTo-Json -Depth 4), $utf8)
    }
    $exitDisplay = if ($null -eq $result.exit_code) { 'UNAVAILABLE' } else { [string]$result.exit_code }
    if (!$Quiet) { Write-Host "Native command exit code: $exitDisplay; timed out: $($result.timed_out). Evidence: $statusPath" }
    if ($stderr.Trim().Length -gt 0) { Write-Host "Native command stderr:`n$stderr" }
    if ($result.timed_out -or $null -eq $result.exit_code -or $result.exit_code -ne 0 -or
        !$result.stdout_complete -or !$result.stderr_complete -or $result.process_error.Length -gt 0) {
        throw "Native command failed (exit $exitDisplay; timed out: $($result.timed_out)). $($result.process_error) Inspect $statusPath and $stderrPath."
    }
    return $result
}
