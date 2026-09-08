$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $projectRoot '.tools'
$archive = Join-Path $toolsDir 'sqlite-amalgamation-3530400.zip'
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
if (!(Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -Uri 'https://www.sqlite.org/2026/sqlite-amalgamation-3530400.zip' -OutFile $archive
}
# SHA-256 of the official archive, verified against its published SHA3-256:
# 628a44cfe82c66aed1ccbbe85a562d2e33ebe64b3288981ed76285612227934e
$expected = '1e71ddf93849c6a6ecf58b827c0692073d2dd7ee40196158068f7b29f422e87d'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLower() -ne $expected) {
    throw 'SQLite checksum mismatch. Archive was not extracted.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $toolsDir -Force
Write-Output 'SQLite 3.53.4 source ready (static build, no DB service).'
