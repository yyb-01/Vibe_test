param([string]$Executable)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$Executable) { $Executable = & (Join-Path $PSScriptRoot 'build-sqlite.ps1') }
$fixture = Join-Path $projectRoot ('.build/sqlite-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
function Run-Phase([string]$Mode, [string]$Path, [int]$Expected = 0) {
    & $Executable $Mode $Path
    if ($LASTEXITCODE -ne $Expected) { throw "SQLite $Mode returned $LASTEXITCODE (expected $Expected)." }
}
Run-Phase 'suite' $fixture
$crash = Join-Path $fixture 'crash.db'
Run-Phase 'crash-before' $crash 73
Run-Phase 'empty' $crash
Run-Phase 'crash-after' $crash 73
Run-Phase 'recover' $crash
Run-Phase 'recover' $crash
$locked = Join-Path $fixture 'locked.db'
$holder = Start-Process -FilePath $Executable -ArgumentList @('hold', ('"' + $locked + '"')) -WindowStyle Hidden -PassThru
try {
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while (!(Test-Path -LiteralPath ($locked + '.ready'))) {
        if ($holder.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'SQLite lock holder failed to start.' }
        Start-Sleep -Milliseconds 100
    }
    Run-Phase 'locked' $locked
} finally {
    if (!$holder.HasExited) { Stop-Process -Id $holder.Id }
    $holder.WaitForExit()
    $holder.Dispose()
}
Run-Phase 'empty' $locked
Write-Output "PASS SQLite restart, rollback, lost ACK, crash recovery, process lock, shutdown/backups ($fixture)"
