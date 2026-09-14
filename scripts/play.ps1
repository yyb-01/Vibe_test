param(
    [ValidateNotNullOrEmpty()][string]$SavePath,
    [ValidateNotNullOrEmpty()][string]$RestoreBackup
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($RestoreBackup -and !$SavePath) { throw 'RestoreBackup requires SavePath for a new save file.' }
if ($SavePath) {
    $exe = & (Join-Path $PSScriptRoot 'build-sqlite.ps1') -Target demo
    if ($RestoreBackup) {
        & $exe --restore ([System.IO.Path]::GetFullPath($RestoreBackup)) ([System.IO.Path]::GetFullPath($SavePath))
        if ($LASTEXITCODE -ne 0) { throw 'Backup restore failed. The destination must be a new save path.' }
    }
    & $exe --save ([System.IO.Path]::GetFullPath($SavePath))
} else {
    & (Join-Path $PSScriptRoot 'build.ps1') -Target demo
    & (Join-Path $projectRoot '.build/astra-demo.exe')
}
if ($LASTEXITCODE -ne 0) { throw 'Sandbox exited with an error.' }
