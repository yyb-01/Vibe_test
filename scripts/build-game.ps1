param([switch]$Release)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $projectRoot '.tools/zig-x86_64-windows-0.15.2/zig.exe'
$sqlite = Join-Path $projectRoot '.tools/sqlite-amalgamation-3530400'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Run scripts/setup-toolchain.ps1 first.' }
if (!(Test-Path -LiteralPath (Join-Path $sqlite 'sqlite3.c'))) { throw 'Run scripts/setup-sqlite.ps1 first.' }
$output = Join-Path $projectRoot '.build'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$previousCache = $env:ZIG_GLOBAL_CACHE_DIR
$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $output 'zig-cache'
try {
    $object = Join-Path $output 'sqlite3.o'
    & $compiler cc -O2 -DSQLITE_THREADSAFE=1 -DSQLITE_OMIT_LOAD_EXTENSION -DSQLITE_DQS=0 -c (Join-Path $sqlite 'sqlite3.c') -o $object
    if ($LASTEXITCODE -ne 0) { throw 'SQLite C build failed.' }
    $sources = @('core','storage','game' | ForEach-Object {
        $pattern = if ($_ -eq 'storage') { 'sqlite*.cpp' } else { '*.cpp' }
        Get-ChildItem -LiteralPath (Join-Path $projectRoot $_) -Filter $pattern | ForEach-Object FullName
    })
    $exe = Join-Path $output 'astra-game.exe'
    $optimization = if ($Release) { '-O2' } else { '-O0' }
    & $compiler c++ -std=c++20 $optimization -g -Wall -Wextra -Werror -pthread -municode -I (Join-Path $projectRoot 'core') -I (Join-Path $projectRoot 'storage') -I $sqlite @sources $object -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Game build failed.' }
    Write-Output $exe
} finally { $env:ZIG_GLOBAL_CACHE_DIR = $previousCache }
