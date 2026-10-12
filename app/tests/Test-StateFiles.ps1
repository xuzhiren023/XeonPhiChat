#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/ChatCore.ps1')
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/Transport.ps1')
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('phi-state-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $tmp
$script:stateTests=0
function Check-State([bool]$Value,[string]$Message) { $script:stateTests++; if (!$Value) { throw "FAIL: $Message" } }
try {
    $path=Join-Path $tmp 'status.json'
    Write-JsonFile $path ([pscustomobject]@{state='running';message='first'})
    Write-JsonFile $path ([pscustomobject]@{state='done';message='second'})
    Check-State ((Read-JsonFile $path).message -ceq 'second') 'existing destination is replaced'
    # Keep an old UI read handle open while replacing the pathname. Both the old
    # document and the newly published document must remain complete/readable.
    $held=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        Write-JsonFile $path ([pscustomobject]@{state='done';message='third'})
        Check-State ((Read-JsonFile $path).message -ceq 'third') 'shared reader allows replacement'
        $reader=New-Object IO.StreamReader($held)
        try { Check-State (($reader.ReadToEnd() | ConvertFrom-Json).message -ceq 'second') 'old read handle retains a complete previous document' }
        finally { $reader.Dispose() }
    } finally { $held.Dispose() }
    Write-Utf8 ($path+'.new') 'unrelated previous temp'
    Write-JsonFile $path ([pscustomobject]@{state='running';message='fourth'})
    Check-State ([IO.File]::ReadAllText($path+'.new') -ceq 'unrelated previous temp') 'writer does not remove another temporary file'

    if (!('PhiChatTests.ConcurrentState' -as [type])) {
        # Reflection reaches the already loaded helper from C# threads without a
        # PowerShell runspace or a dependency on an on-disk compiled assembly.
        Add-Type -TypeDefinition @'
using System;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Text.RegularExpressions;
namespace PhiChatTests {
    public static class ConcurrentState {
        public static void Run(Type type, string path) {
            var write = type.GetMethod("WriteText", new Type[] {typeof(string), typeof(string)});
            var read = type.GetMethod("ReadText");
            string payload = new String('x', 300);
            Action<int> writer = id => {
                for (int n = 0; n < 50; ++n) {
                    string text = "{\"writer\":" + id + ",\"sequence\":" + n + ",\"payload\":\"" + payload + "\"}";
                    write.Invoke(null, new object[] {path, text});
                    Thread.Sleep(1);
                }
            };
            writer(0);
            Task a = Task.Factory.StartNew(() => writer(1));
            Task b = Task.Factory.StartNew(() => writer(2));
            int count = 0;
            try {
                while (!a.IsCompleted || !b.IsCompleted || count < 20) {
                    string text = (string)read.Invoke(null, new object[] {path});
                    if (!Regex.IsMatch(text, "^\\{\"writer\":[012],\"sequence\":[0-9]+,\"payload\":\"x{300}\"\\}$"))
                        throw new Exception("Reader observed partial or mixed JSON");
                    ++count;
                }
            } finally {
                // Finish fixture writers before PowerShell removes their directory.
                Task.WaitAll(a, b);
            }
        }
    }
}
'@
    }
    try { [PhiChatTests.ConcurrentState]::Run([PhiChat.StateFiles],(Join-Path $tmp 'concurrent.json')) }
    catch { Write-Output $_.Exception.ToString(); throw }
    Check-State $true 'concurrent writers/readers observe complete documents'
    Check-State (@(Get-ChildItem -LiteralPath $tmp -Filter 'concurrent.json.*.new').Count -eq 0) 'owned temporary files are gone after success'

    $directory=Join-Path $tmp 'blocked.json'; $null=New-Item -ItemType Directory -Path $directory
    $problem=''; try { Write-JsonFile $directory @{state='done'} } catch { $problem=$_.Exception.Message }
    Check-State ($problem.Contains($directory) -and $problem.Contains('directory')) 'directory collision names its exact path'
    Check-State (Test-Path -LiteralPath $directory -PathType Container) 'conflicting directory is preserved'

    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $before=[IO.File]::ReadAllText($path)
        $held=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
        try {
            $problem=''; $watch=[Diagnostics.Stopwatch]::StartNew()
            try { [PhiChat.StateFiles]::WriteText($path,'{"state":"wrong"}',120) } catch { $problem=$_.Exception.Message }
            Check-State ($problem.Contains($path) -and $watch.Elapsed.TotalSeconds -lt 3) 'Windows non-delete-sharing reader fails with bounded path-specific error'
        } finally { $held.Dispose() }
        Check-State ([IO.File]::ReadAllText($path) -ceq $before) 'failed replacement keeps last complete state'
        Check-State (@(Get-ChildItem -LiteralPath $tmp -Filter 'status.json.*.new').Count -eq 0) 'failed writer cleans only its own temporary state'
    } else { Write-Output 'SKIP: Windows non-delete-sharing lock behavior requires Windows; concurrent publication was tested above.' }

    $script:job=$tmp
    try { throw 'fixture original load failure' } catch { Write-JobFailure $_ }
    $failure=Read-JsonFile (Join-Path $tmp 'failure.json')
    Check-State ($failure.state -ceq 'failed' -and $failure.message -ceq 'fixture original load failure') 'original error has an independent failure record'
    Check-State ($failure.script_line -gt 0 -and $failure.stack) 'failure record includes script location'
    Write-Output "PASS: $script:stateTests state-file checks"
} finally { Remove-Item -LiteralPath $tmp -Recurse -Force }
