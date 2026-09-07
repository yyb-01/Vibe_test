$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $projectRoot '.tools/zig-x86_64-windows-0.15.2/zig.exe'
$postgres = Join-Path $projectRoot '.tools/postgresql-17.11-3/pgsql'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Run scripts/setup-toolchain.ps1 first.' }
if (!(Test-Path -LiteralPath (Join-Path $postgres 'include/libpq-fe.h'))) { throw 'Run scripts/setup-postgres.ps1 first.' }
$output = Join-Path $projectRoot '.build'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$previousCache = $env:ZIG_GLOBAL_CACHE_DIR
$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $output 'zig-cache'
try {
    $sources = @('core','storage','integration') | ForEach-Object {
        Get-ChildItem -LiteralPath (Join-Path $projectRoot $_) -Filter '*.cpp' | ForEach-Object FullName
    }
    $exe = Join-Path $output 'astra-postgres.exe'
    & $compiler c++ -std=c++20 -O0 -g -Wall -Wextra -Werror -pthread -I (Join-Path $projectRoot 'core') -I (Join-Path $projectRoot 'storage') -I (Join-Path $postgres 'include') @sources (Join-Path $postgres 'lib/libpq.lib') -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL integration build failed.' }
    Write-Output $exe
} finally { $env:ZIG_GLOBAL_CACHE_DIR = $previousCache }
