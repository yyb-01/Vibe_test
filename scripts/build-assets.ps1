$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$source=Join-Path $projectRoot '.tools/mikktspace'
New-Item -ItemType Directory -Force -Path $source | Out-Null
$hashes=@{ 'mikktspace.c'='de87e74107df766ce68108801262bd8d53899414236b59810509a8fc2a51e288'; 'mikktspace.h'='17fc433894f24c73753d548086cc4d8c5c0379f4a6edfb98b5da243e4f0bc3d0' }
foreach($name in $hashes.Keys) {
    $file=Join-Path $source $name
    if(!(Test-Path -LiteralPath $file)) {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/mmikk/MikkTSpace/3e895b49d05ea07e4c2133156cfa94369e19e409/$name" -OutFile $file
    }
    if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -ne $hashes[$name]) { throw 'MikkTSpace source checksum mismatch.' }
}
$compiler=Join-Path $projectRoot '.tools/zig-x86_64-windows-0.15.2/zig.exe'
$output=Join-Path $projectRoot '.build'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$previousCache=$env:ZIG_GLOBAL_CACHE_DIR
$env:ZIG_GLOBAL_CACHE_DIR=Join-Path $output 'zig-cache'
try {
    $object=Join-Path $output 'mikktspace.o'
    & $compiler cc -O2 -I $source -c (Join-Path $source 'mikktspace.c') -o $object
    if($LASTEXITCODE -ne 0) { throw 'MikkTSpace build failed.' }
    $exe=Join-Path $output 'astra-mikk.exe'
    & $compiler c++ -std=c++20 -O2 -Wall -Wextra -Werror -I $source (Join-Path $projectRoot 'tools/mikk.cpp') $object -o $exe
    if($LASTEXITCODE -ne 0) { throw 'MikkTSpace adapter build failed.' }
    Write-Output $exe
} finally { $env:ZIG_GLOBAL_CACHE_DIR=$previousCache }
