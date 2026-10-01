# 생존 권위 처리 측정 — 2026-10-01

`.build/astra-game.exe`의 Release 빌드에 native bridge를 통해 입력하고 SQLite WAL/FULL 확정 ACK까지 측정했다. 초기 장면은 차량 1대·좀비 8개·인벤토리 20개이며 1계정만 활성화했다. 60 tick warmup 뒤 300 tick을 측정하고 12 tick마다 공개 view를 읽었다.

| 항목 | p50 | p95 | p99 | 최대 |
|---|---:|---:|---:|---:|
| tick 저장 ACK | 15.561ms | 16.546ms | 17.047ms | 17.402ms |
| 공개 view | 1.335ms | 1.599ms | 1.736ms | 1.736ms |

Windows 11 build 26200에서 실행했다. 최대 view는 4,334B, 관측 DB 파일은 270,336B다. 원본 필드와 scope는 [측정 JSON](GAME_BENCHMARK_2026-10-01.json)에 보존했다.

**p99 17.047ms는 60Hz 예산 16.67ms를 초과하므로 미달이다.** 순차 tick ACK 측정이며 60Hz paced wall-clock 지속 실행이나 UE 렌더/GPU, 원격 네트워크 지연, G.5 최대 콘텐츠 장면의 결과가 아니다. 20계정 benchmark 옵션은 제공하지만 이 표는 1인 결과만 포함한다. 최대 장면·실제 20대 PC·8시간 soak는 아직 측정하지 않았다.

## 재현

```powershell
./scripts/build-game.ps1 -Release
python -m game_tests.benchmark --players 1 --warmup 60 --ticks 300 --output .build/game-benchmark/player1.json
python -m game_tests.benchmark --players 20 --warmup 60 --ticks 300 --output .build/game-benchmark/player20.json
```

각 실행은 `.build/game-benchmark/` 아래 임시 월드를 만들고 종료 후 삭제한다. 측정값은 CPU·디스크·백그라운드 부하에 따라 달라진다. 현재 전체 gameplay 직렬화/checkpoint BLOB 쓰기와 단일 저장 worker의 비용이 남아 있다. 검증된 불변 game state cache와 SQLite 연결 재사용을 적용했지만 시간 예산 충족으로 계산하지 않는다.
