param([string]$Executable)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!$Executable) { $Executable = & (Join-Path $PSScriptRoot 'build-sqlite.ps1') -Target demo }
$save = Join-Path $root ('.build/idle-' + [guid]::NewGuid().ToString('N') + '.db')
$info = New-Object System.Diagnostics.ProcessStartInfo
$info.FileName = $Executable
$info.Arguments = '--client "' + $save + '"'
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardInput = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$process = [System.Diagnostics.Process]::Start($info)
try {
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $notice = $process.StandardError.ReadLineAsync()
    $process.StandardInput.WriteLine('show')
    $process.StandardInput.Write('recon') # A partial line must not block the owner tick.
    $process.StandardInput.Flush()
    if (!$notice.Wait(10000)) { throw 'Idle tick did not expire the snapshot lease before input completed.' }
    if ($notice.Result -ne 'Idle transport: NotAccessible. Use reconnect.') { throw "Unexpected idle error: $($notice.Result)" }
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.WriteLine('nect')
    $process.StandardInput.WriteLine('show')
    $process.StandardInput.WriteLine('quit')
    $process.StandardInput.Flush() # Leave stdin open: quit must not wait for another line.
    if (!$process.WaitForExit(10000)) { throw 'Quit waited for open stdin.' }
    if ($process.ExitCode -ne 0 -or $stderr.Result) { throw "Idle recovery failed: $($stderr.Result)" }
    if ($stdout.Result -notmatch 'Client reconnected; view refreshed' -or
        [regex]::Matches($stdout.Result, 'item 100 def=1 qty=20').Count -ne 2) {
        throw 'Idle reconnect lost the snapshot or partial command.'
    }
    Write-Output 'PASS idle tick, partial input, reconnect, and quit with open stdin'
} finally {
    if (!$process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose()
}
