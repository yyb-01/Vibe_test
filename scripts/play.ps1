$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'build.ps1') -Target demo
& (Join-Path $projectRoot '.build/astra-demo.exe')
if ($LASTEXITCODE -ne 0) { throw 'Sandbox exited with an error.' }
