$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $projectRoot '.tools'
$archive = Join-Path $toolsDir 'zig-0.15.2.zip'
$compiler = Join-Path $toolsDir 'zig-x86_64-windows-0.15.2/zig.exe'
if (Test-Path -LiteralPath $compiler) { & $compiler version; exit $LASTEXITCODE }
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
if (!(Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://ziglang.org/download/0.15.2/zig-x86_64-windows-0.15.2.zip' -OutFile $archive
}
$expected = '3a0ed1e8799a2f8ce2a6e6290a9ff22e6906f8227865911fb7ddedc3cc14cb0c'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLower() -ne $expected) {
    throw 'Toolchain checksum mismatch. Archive was not executed or extracted.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $toolsDir
& $compiler version
if ($LASTEXITCODE -ne 0) { throw 'Toolchain validation failed.' }
