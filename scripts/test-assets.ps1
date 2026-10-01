param([string]$Python)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if(!$Python){
    $Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if(!(Test-Path -LiteralPath $Python)){$Python=(Get-Command python -ErrorAction Stop).Source}
}
if(!(Test-Path -LiteralPath (Join-Path $projectRoot '.build/astra-mikk.exe'))){& (Join-Path $PSScriptRoot 'build-assets.ps1') | Out-Null}
if(!(Test-Path -LiteralPath (Join-Path $projectRoot '.tools/directxtex/texconv.exe'))){& (Join-Path $PSScriptRoot 'setup-asset-tools.ps1') | Out-Null}
Push-Location -LiteralPath $projectRoot
try{
    & $Python -m game_tests.assets
    if($LASTEXITCODE -ne 0){throw 'Asset gate/cook checks failed.'}
}finally{Pop-Location}
