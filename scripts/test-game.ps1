param([string]$Python,[string]$Executable)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if(!$Python){
    $Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if(!(Test-Path -LiteralPath $Python)){$Python=(Get-Command python -ErrorAction Stop).Source}
}
if(!$Executable){
    $Executable=Join-Path $projectRoot '.build/astra-game.exe'
    if(!(Test-Path -LiteralPath $Executable)){& (Join-Path $PSScriptRoot 'build-game.ps1') -Release | Out-Null}
}
$Executable=(Resolve-Path -LiteralPath $Executable).Path
Push-Location -LiteralPath $projectRoot
try{
    & $Python -m game_tests.native --executable $Executable
    if($LASTEXITCODE -ne 0){throw 'Survival/TLS/SQLite checks failed.'}
}finally{Pop-Location}
