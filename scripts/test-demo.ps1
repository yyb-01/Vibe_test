param([string]$Executable, [switch]$ClientMode)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!$Executable) { $Executable = & (Join-Path $PSScriptRoot 'build-sqlite.ps1') -Target demo }
$fixture = Join-Path $root ('.build/demo-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$save = Join-Path $fixture '월드 저장.db'
function Run([string[]]$Lines, [int]$Expected = 0, [string]$Backup) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $mode = if ($ClientMode) { '--client' } else { '--save' }
    $info.Arguments = $mode + ' "' + $save + '"'
    if ($Backup) { $info.Arguments = '--restore "' + $Backup + '" "' + $save + '"' }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($info)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        foreach ($line in $Lines) { $process.StandardInput.WriteLine($line) }
        $process.StandardInput.Close()
        if (!$process.WaitForExit(15000)) { $process.Kill(); throw 'Demo timed out.' }
        if ($process.ExitCode -ne $Expected) { throw "Demo exit $($process.ExitCode): $($stderr.Result)" }
        return $stdout.Result + $stderr.Result
    } finally { $process.Dispose() }
}
function Expect([string]$Text, [string]$Pattern) {
    if ($Text -notmatch $Pattern) { throw "Missing pattern $Pattern in: $Text" }
}
$first = Run @('split 100 7 20 4 0','replay','show','quit')
if ($ClientMode) { Expect $first 'Client protocol mode: in-process only' }
Expect $first 'created=2:1'
Expect $first 'item 100 def=1 qty=13'
if ([regex]::Matches($first, 'Committed to SQLite sequence=1').Count -ne 2) { throw 'Replay duplicated a transaction.' }
$second = Run @('move 2:1 20 65536 0','move 2:1 20 -1 0','move 2:1 20 32 0','move 2:1 20 5 0','quit')
Expect $second 'Expected an unsigned integer in range'
Expect $second 'InvalidPlacement'
Expect $second 'Committed to SQLite sequence=2'
$third = Run @('show','merge 2:1 10 0 0','show')
Expect $third 'item 2:1 def=1 qty=7 grid=5,0'
Expect $third 'Committed to SQLite sequence=3'
Expect $third 'item 100 def=1 qty=20'
$null = Run @('show','quit')
if (@(Get-ChildItem -LiteralPath ($save + '.backups') -Filter '*.sqlite3').Count -ne 3) { throw 'Backup count mismatch.' }
if (!(Test-Path -LiteralPath $save)) { throw 'Save path changed.' }
$original = $save
$backup = (Get-ChildItem -LiteralPath ($save + '.backups') -Filter '*.sqlite3' | Sort-Object Name)[0].FullName
$save = Join-Path $fixture 'restored.db'
Expect (Run @() 0 $backup) 'Snapshot sequence=2'
Expect (Run @('show','quit')) 'item 100 def=1 qty=13'
$save = $original
[System.IO.File]::WriteAllText($save, 'corrupt fixture')
$null = Run @() 1
if ([System.IO.File]::ReadAllText($save) -ne 'corrupt fixture') { throw 'Save overwritten.' }
if ($ClientMode) {
    $save = Join-Path $fixture 'client-reconnect.db'
    $resumed = Run @('submit split 100 7 20 4 0','disconnect','show','replay','reconnect','replay','move 2:1 20 5 0','show','disconnect','quit')
    Expect $resumed 'Client disconnected'
    Expect $resumed 'NotAccessible'
    Expect $resumed 'Client reconnected; view refreshed'
    Expect $resumed 'Committed to SQLite sequence=1'
    Expect $resumed 'Committed to SQLite sequence=2'
    Expect $resumed 'item 100 def=1 qty=13'
    Expect $resumed 'item 2:1 def=1 qty=7 grid=5,0'
    $persisted = Run @('show','move 2:1 20 6 0','quit')
    Expect $persisted 'Committed to SQLite sequence=3'
    Expect $persisted 'item 100 def=1 qty=13'
    $save = Join-Path $fixture 'client-offline-quit.db'
    $null = Run @('submit split 100 7 20 4 0','disconnect','quit')
    Expect (Run @('show','quit')) 'item 100 def=1 qty=13'
    $save = Join-Path $fixture 'client-sequence.db'
    $cursor = Run @('take 100 32 0','disconnect','reconnect','take 100 4 0','disconnect','reconnect','drop 100','show','quit')
    Expect $cursor 'InvalidPlacement'
    Expect $cursor 'Committed to SQLite sequence=1'
    Expect $cursor 'Committed to SQLite sequence=2'
    if ($cursor -match 'RevisionConflict|IdempotencyMismatch') { throw 'Resume returned a stale action sequence.' }
    $save = Join-Path $fixture 'client-burst.db'
    $lines = @('split 100 7 20 4 0') + (@('replay') * 25) + @('move 2:1 20 5 0','show','quit')
    $burst = Run $lines
    Expect $burst 'Committed to SQLite sequence=2'
    Expect $burst 'item 2:1 def=1 qty=7 grid=5,0'
    if ([regex]::Matches($burst, 'Committed to SQLite sequence=1').Count -ne 26) {
        throw 'A rate-limited replay regressed the confirmed result.'
    }
}
Write-Output "PASS saved demo and backup restore (ClientMode=$ClientMode)"
