param([ValidateSet('test','demo')][string]$Target = 'test')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $projectRoot '.tools/zig-x86_64-windows-0.15.2/zig.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Run scripts/setup-toolchain.ps1 first.' }
$output = Join-Path $projectRoot '.build'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$previousCache = $env:ZIG_GLOBAL_CACHE_DIR
$env:ZIG_GLOBAL_CACHE_DIR = Join-Path $output 'zig-cache'
try {
    $sources = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'core') -Filter '*.cpp' | ForEach-Object FullName)
    $sourceDir = if ($Target -eq 'test') { 'tests' } else { 'demo' }
    $sources += @(Get-ChildItem -LiteralPath (Join-Path $projectRoot $sourceDir) -Filter '*.cpp' | ForEach-Object FullName)
    $exe = Join-Path $output "astra-$Target.exe"
    & $compiler c++ -std=c++20 -O0 -g -Wall -Wextra -Werror -pthread -I (Join-Path $projectRoot 'core') @sources -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'C++ build failed.' }
    if ($Target -eq 'test') {
        & $exe
        if ($LASTEXITCODE -ne 0) { throw 'C++ tests failed.' }
    } else { Write-Output $exe }
} finally { $env:ZIG_GLOBAL_CACHE_DIR = $previousCache }
