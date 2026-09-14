param(
    [ValidateRange(5,60000)][int[]]$Items = @(100,1000,10000,60000),
    [ValidateRange(3,1000)][int]$Samples = 20,
    [string]$Executable,
    [switch]$Async
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!$Executable) { $Executable = & (Join-Path $PSScriptRoot 'build-sqlite.ps1') -Target benchmark }
$output = Join-Path $root ('.build/benchmarks/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $output | Out-Null
$rows = @(foreach ($count in $Items) {
    $database = Join-Path $output ($count.ToString() + '-' + [guid]::NewGuid().ToString('N') + '.db')
    Write-Host "Measuring $count items, $Samples samples..."
    $flags = @(if ($Async) { '--async' })
    $csv = @(& $Executable $database $count $Samples @flags)
    if ($LASTEXITCODE -ne 0) { throw "Benchmark failed for $count items." }
    $csv | ConvertFrom-Csv
})
$rows | Export-Csv -LiteralPath (Join-Path $output 'results.csv') -NoTypeInformation -Encoding utf8
if ($Async) { $rows | Format-Table items,message_budget_bytes,submit_p50_ms,resolve_peak_p50_ms,roundtrip_p50_ms }
else { $rows | Format-Table items,checkpoint_p50_ms,encode_p50_ms,sqlite_save_p50_ms,commit_p50_ms }
Write-Output "Results: $output"
