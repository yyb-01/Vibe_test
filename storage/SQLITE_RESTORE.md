# 백업을 새 월드로 복원

먼저 원래 월드를 `quit`으로 정상 종료합니다. 복원하려는 시점 이후의 진행은 복원본에 포함되지 않습니다. 원래 세이브와 선택한 백업은 보존하고 새 저장 파일을 만듭니다.

프로젝트 폴더에서 백업 목록을 확인하고 원하는 파일을 선택합니다.

```powershell
Get-ChildItem ./saves/world.db.backups -Filter 'backup-*.sqlite3' | Sort-Object Name
./scripts/play.ps1 -RestoreBackup ./saves/world.db.backups/backup-00000000000000000002.sqlite3 -SavePath ./saves/restored-world.db
```

위 백업 이름은 예시입니다. 목록에 나온 실제 파일명으로 바꿉니다. 성공하면 선택한 체크포인트의 확정 순번을 표시하고 복원한 월드를 실행합니다. 이후에는 `./scripts/play.ps1 -SavePath ./saves/restored-world.db`로 다시 엽니다.

복원만 수행하려면 SQLite 데모 실행물의 `--restore BACKUP NEW_PATH`를 사용합니다. 저장소 API는 `restore_sqlite_backup(backup, destination, expectedCatalog)`이며, 반환값은 백업의 확정 순번입니다. 복원은 로딩 전의 동기 작업입니다.

원본은 앱 잠금을 확보할 수 있는 닫힌 DELETE-mode SQLite 파일이어야 합니다. DB 무결성, schema 버전, 체크포인트 불변식, catalog 호환성과 다음 세션의 epoch/origin 한도를 확인합니다. 원본에 WAL/SHM/journal이 남아 있으면 거절하며, 수동으로 지워서 우회하지 않습니다. 실행 중인 월드 DB 파일 대신 정상 종료로 생성한 백업 파일을 선택합니다.

대상 DB, WAL/SHM/journal 또는 대상의 백업 폴더가 이미 있으면 복원하지 않습니다. 백업 순환 정리의 영향을 받지 않도록 `.backups` 폴더 내부도 대상으로 사용할 수 없습니다. 새 부모 폴더는 자동 생성합니다. SQLite Backup API로 임시 사본을 만들고 원본 체크포인트와 비교한 뒤 덮어쓰기 없이 게시합니다. `.lock`은 프로세스 간 잠금을 위한 파일이므로 실패 후에도 남을 수 있습니다.

복원본은 독립된 세이브 계열(lineage)입니다. 자산 ID와 요청 결과는 백업 그대로 유지하고, 실제 실행 시 기존 acquire 경로가 epoch/origin을 증가시킵니다. 서로 다른 복제·복원 파일 사이의 ID 유일성이나 자산 병합은 지원하지 않습니다.

검증: `scripts/test-sqlite.ps1`, `scripts/test-demo.ps1`. 원본/백업 바이트 보존, 기존 대상·잠금·잔여 WAL·catalog 불일치·손상 거절, 복원 후 중복 요청·새 거래·재시작, 과거 시점의 콘솔 복원을 확인합니다. Windows Zig에서 검증했으며 실제 전원 차단과 Windows 외 플랫폼은 미검증입니다.
