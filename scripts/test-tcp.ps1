$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $root '.tools/zig-x86_64-windows-0.15.2/zig.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Run scripts/setup-toolchain.ps1 first.' }
$output = Join-Path $root '.build'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$previousCache = $env:ZIG_GLOBAL_CACHE_DIR
$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $output 'zig-cache'
try {
    $sources = foreach ($dir in @('core','net','network_tests')) {
        Get-ChildItem -LiteralPath (Join-Path $root $dir) -Filter '*.cpp' | ForEach-Object FullName
    }
    $exe = Join-Path $output 'astra-tcp-tests.exe'
    & $compiler c++ -std=c++20 -O0 -g -Wall -Wextra -Werror -pthread -I (Join-Path $root 'core') @sources -lws2_32 -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'TCP test build failed.' }
    & $exe
    if ($LASTEXITCODE -ne 0) { throw 'TCP tests failed.' }
} finally { $env:ZIG_GLOBAL_CACHE_DIR = $previousCache }
