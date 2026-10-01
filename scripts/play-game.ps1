param([ValidateSet('solo','host','join')][string]$Mode='solo', [string]$WorldId='survival',
      [string]$Invitation, [string]$Address='127.0.0.1', [int]$Port=7777, [switch]$Rebuild,
      [string]$Python)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if (!$Python) {
    $Python=Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if (!(Test-Path -LiteralPath $Python)) { $Python=(Get-Command python -ErrorAction Stop).Source }
}
if ($Rebuild -or !(Test-Path -LiteralPath (Join-Path $projectRoot '.build/astra-game.exe'))) {
    & (Join-Path $PSScriptRoot 'build-game.ps1') -Release | Out-Null
}
$options=@('-m','game_launcher','--mode',$Mode,'--world',$WorldId,'--address',$Address,'--port',"$Port")
if ($Invitation) { $options+=@('--invitation',$Invitation) }
Push-Location -LiteralPath $projectRoot
try {
    & $Python @options
    if ($LASTEXITCODE -ne 0) { throw 'Game launcher failed; the save was preserved.' }
} finally { Pop-Location }
