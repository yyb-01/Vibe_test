$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$pgBin = Join-Path $projectRoot '.tools/postgresql-17.11-3/pgsql/bin'
$exe = Join-Path $projectRoot '.build/astra-postgres.exe'
if (!(Test-Path -LiteralPath $exe)) { throw 'Run scripts/build-postgres.ps1 first.' }
if (!(Test-Path -LiteralPath (Join-Path $pgBin 'initdb.exe'))) { throw 'Run scripts/setup-postgres.ps1 first.' }
$testRoot = Join-Path $projectRoot ('.build/pg-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$taskData = Join-Path $testRoot 'data'
$taskLog = Join-Path $testRoot 'server.log'
$passwordFile = Join-Path $testRoot 'password.tmp'
$taskPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
$previousPath = $env:PATH
$previousPassword = $env:PGPASSWORD
$previousConnection = $env:ASTRA_TEST_CONNINFO
$started = $false
function Start-TestPostgres {
    $taskServerOptions = "-h 127.0.0.1 -p $taskPort -c max_connections=20"
    $taskCtlArgs = @('-D', "`"$taskData`"", '-l', "`"$taskLog`"", '-o', "`"$taskServerOptions`"", '-w', 'start')
    $process = Start-Process -FilePath (Join-Path $pgBin 'pg_ctl.exe') -ArgumentList $taskCtlArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $testRoot 'start.stdout') -RedirectStandardError (Join-Path $testRoot 'start.stderr')
    # PowerShell -Wait includes descendants, which would wait for postgres itself.
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Test PostgreSQL failed to start. See $taskLog" }
}
try {
    $env:PATH = $pgBin + ';' + $previousPath
    $env:PGPASSWORD = $taskPassword
    [System.IO.File]::WriteAllText($passwordFile, $taskPassword, [System.Text.UTF8Encoding]::new($false))
    & (Join-Path $pgBin 'initdb.exe') -D $taskData -U astra_test --auth=scram-sha-256 --pwfile=$passwordFile --encoding=UTF8 --no-locale | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Test initdb failed.' }
    Remove-Item -LiteralPath $passwordFile
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $taskPort = $listener.LocalEndpoint.Port
    $listener.Stop()
    $env:ASTRA_TEST_CONNINFO = "host=127.0.0.1 port=$taskPort user=astra_test dbname=postgres password=$taskPassword connect_timeout=5 application_name=astra_integration"
    Start-TestPostgres
    $started = $true
    & (Join-Path $pgBin 'psql.exe') -X -h 127.0.0.1 -p $taskPort -U astra_test -d postgres -v ON_ERROR_STOP=1 -f (Join-Path $projectRoot 'storage/schema.sql') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Test schema migration failed.' }
    & $exe functional
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL functional tests failed.' }
    & $exe crash
    if ($LASTEXITCODE -ne 73) { throw 'Expected process exit 73 after DB commit.' }
    & (Join-Path $pgBin 'pg_ctl.exe') -D $taskData -m immediate -w stop | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Test crash shutdown failed.' }
    $started = $false
    Start-TestPostgres
    $started = $true
    & $exe recover
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL crash recovery tests failed.' }
    Write-Output 'PASS all PostgreSQL integration phases'
} finally {
    if ($started) {
        & (Join-Path $pgBin 'pg_ctl.exe') -D $taskData -m fast -w stop | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Warning "Test server cleanup failed. Data directory: $taskData" }
    }
    if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile }
    $env:PATH = $previousPath
    $env:PGPASSWORD = $previousPassword
    $env:ASTRA_TEST_CONNINFO = $previousConnection
}
