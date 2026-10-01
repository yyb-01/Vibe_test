# 엔진 독립 에셋 도구

Python 3.12+와 `requirements.txt`의 NumPy/Pillow/cryptography를 사용한다. 소스는 읽기 전용으로 다루고 정규화 출력·검증·cook를 별도 경로에 만든다.

```powershell
python -m pip install -r requirements.txt
./scripts/setup-toolchain.ps1
./scripts/build-assets.ps1
./scripts/setup-asset-tools.ps1
./scripts/test-assets.ps1
python -m asset_tools --help
```

## 처리와 검증

1. `normalize`: JSON/OBJ 또는 단일 rigid glTF/GLB를 읽어 단위·basis·datum을 맞춘다. 반사, 비정상 scale, 경로 이탈과 입력 상한을 거절한다. 변환/skin/sparse/multi-mesh glTF는 현재 지원하지 않는다.
2. `bake`: 공식 MikkTSpace tangent와 CPU high→low cage ray로 DirectX normal을 만든다. 검증 시 소스로 다시 bake해 miss/normal 증거를 대조한다.
3. `golden`: D65·0.18 gray card·고정 노출로 9뷰와 debug buffer를 만든다. 검증 시 실제 소스에서 다시 렌더해 hash만 바꾼 위조 결과도 거절한다.
4. `validate`: topology/교차/폐쇄 부피·quad 비율·UV overlap/gutter/density, socket/datum, PBR 범위, CIEDE2000 색차와 bake/golden 증거를 검사한다.
5. `keygen`, `approve`: Ed25519 키와 내용 hash에 결합한 reviewer/checks 승인을 만든다. 에셋 승인에는 `--kind asset --style <style.json>`을 지정하고 validate를 먼저 통과해야 한다.
6. `cook`, `verify`: 신뢰 public key로 style/asset 승인을 확인하고 서명된 manifest·128B header·80B socket·mesh/LOD/physics/skeleton·BC7/BC5 전체 mip chain을 묶는다. 변경된 파일/승인/서명을 거절하고 기존 버전 출력은 덮어쓰지 않는다.

각 명령의 필수 입력은 `python -m asset_tools <명령> --help`에 있다. 승인 private key는 배포 소스/결과에 포함하지 않는다. 자동 fixture의 임시 키/승인은 도구 검증용이며 사람의 production 아트 승인으로 계산하지 않는다.

## 현재 콘텐츠와 한계

`assets/style_pack.json`은 승인 대기 `mil_apoc_v1`이다. 6 master·4 material·18 bone 이름과 class budget을 정의하지만 datum template은 테스트용 `datum_fixture_v1` 하나다. 회전/skin pose·전체 skeleton·실제 Picatinny/MOLLE/bolt 접합면·gold asset 20~30개와 100개 pilot·대상 엔진 렌더 검증은 남아 있다. 현재 시험은 절차적으로 만든 cube fixture다.

MikkTSpace는 [공식 소스](https://github.com/mmikk/MikkTSpace)의 commit `3e895b49d05ea07e4c2133156cfa94369e19e409`에 고정하고 C/H SHA-256을 검사한다. texconv는 [Microsoft DirectXTex may2026](https://github.com/microsoft/DirectXTex/releases/tag/may2026) 실행물 SHA-256을 검사한다. 원본 license/header는 다운로드한 도구와 함께 `.tools/`에 보존한다. CPU BC7 sRGB/BC5 normal/BC7 ORM 압축을 풀어 색차·각도·채널 오차도 재검증한다.
