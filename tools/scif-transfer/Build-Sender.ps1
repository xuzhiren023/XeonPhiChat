#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$OutputPath)
$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:exe /platform:x64 /optimize+ ('/out:'+([IO.Path]::GetFullPath($OutputPath))) (Join-Path $PSScriptRoot 'ScifSend.cs')
if ($LASTEXITCODE -ne 0) {throw 'SCIF sender compilation failed.'}
Write-Output 'Windows x64 SCIF sender compiled; no driver/card calls performed.'
