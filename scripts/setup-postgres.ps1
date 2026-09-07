$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $projectRoot '.tools/postgresql-17.11-3.zip'
$destination = Join-Path $projectRoot '.tools/postgresql-17.11-3'
$server = Join-Path $destination 'pgsql/bin/postgres.exe'
if (Test-Path -LiteralPath $server) { & $server --version; exit $LASTEXITCODE }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archive) | Out-Null
if (!(Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://get.enterprisedb.com/postgresql/postgresql-17.11-3-windows-x64-binaries.zip' -OutFile $archive
}
# Pinned from the EDB HTTPS artifact used for this integration; a reproducibility check.
$expected = '4b8db0930c38f6ef845db919551dedda3b6b845aeb0927b3d79a6e8e9e4537cf'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLower() -ne $expected) {
    throw 'PostgreSQL archive checksum mismatch; not extracted.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $destination
& $server --version
if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL validation failed.' }
