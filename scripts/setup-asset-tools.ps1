$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$target = Join-Path $projectRoot '.tools/directxtex'
New-Item -ItemType Directory -Force -Path $target | Out-Null
$exe = Join-Path $target 'texconv.exe'
$expected = 'DCFDEC10244E02CF5037FBA089C55FB7E1326B1C8181742D77D15FA5CB5EEF06'
if (!(Test-Path -LiteralPath $exe) -or (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne $expected) {
    Invoke-WebRequest -Uri 'https://github.com/microsoft/DirectXTex/releases/download/may2026/texconv.exe' -OutFile $exe
}
if ((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash -ne $expected) { throw 'Official texconv SHA-256 mismatch.' }
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/microsoft/DirectXTex/may2026/LICENSE' -OutFile (Join-Path $target 'LICENSE')
Write-Output 'Microsoft DirectXTex may2026 ready.'
