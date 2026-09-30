# 자유비행 합성 측정

2026-09-28 현재 로컬 Windows 환경, Zig 0.15.2 C++20 `-O2`, 단일 스레드.
2,048개의 동일한 900m/s 탄환, 기본 중력, `dragPpt=170`에서 30회 측정했다.
표본 하나는 전체 탄환의 자유비행 4 substep이다. 30개 정렬값의 index 15/28을
p50/p95로 표시했다. 측정 직전·직후의 머신 부하를 통제한 반복 통계는 아니다.

| 구현 | p50 | p95 | 마지막 첫 탄환 x(μm) |
|---|---:|---:|---:|
| 모든 곱에 128회 비트 나눗셈 | 17.1667ms | 21.7491ms | 433617777 |
| 64bit 곱 직접 나눗셈 + 넓은 곱 64회 비트 나눗셈 | 2.9654ms | 3.4758ms | 433617777 |
| `std::gcd` 약분 추가, 최종 소스 빌드 | 1.9237ms | 2.6028ms | 433617777 |

최적화는 작은 곱에 정수 `/`와 `%`를 사용하고, 넓은 곱은 상위 limb를 초기 나머지로
사용한다. nearest-even, 부호, overflow 검사는 유지했다. 독립 BigInt 예상값과
INT64_MIN·반올림 경계 등을 포함해 코어 86그룹이 통과했다.
이후 분자 인자와 분모의 공약수를 `std::gcd`로 제거해 같은 유리수의 중간 곱을
줄였다. 0 곱도 분모 검증 후 바로 반환한다. 약분 뒤의 양·음수 tie, 넓은 곱,
0/0 거절을 추가 검증했다. 같은 세션에서 연달아 실행한 비교는 기존 p50 3.1394ms,
약분 후보 1.9601ms였으며, 위 마지막 행은 실제 반영된 최종 코드의 재빌드 결과다.

이 측정에는 충돌, 적응 분할, history, SIMD, 피해, 저장, UE 렌더링이 없다.
명세의 전투 전체 2ms 예산이나 실제 60fps 통과 증거로 사용할 수 없다.

재현용 측정 본문은 다음과 같다. 프로젝트 `core/ballistics.cpp`, `core/fixed_math.cpp`와
함께 컴파일하고 `core`를 include 경로로 지정한다. 실행했던 소스/실행물은 `.build/ballistics-benchmark.*`다.

```cpp
#include "ballistics.hpp"
#include <algorithm>
#include <chrono>
#include <iostream>
#include <vector>
int main() {
    using namespace astra::ballistics;
    std::vector<Flight> bullets(2048, Flight{{}, {900000000, 0, 0}});
    Atmosphere air; air.dragPpt = 170;
    std::vector<double> samples;
    for (int tick = 0; tick < 30; ++tick) {
        auto start = std::chrono::steady_clock::now();
        for (int sub = 0; sub < 4; ++sub)
            for (auto& bullet : bullets) bullet = free_flight(bullet, air);
        samples.push_back(std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - start).count());
    }
    std::sort(samples.begin(), samples.end());
    std::cout << samples[15] << ' ' << samples[28] << ' '
              << bullets.front().position[0] << '\n';
}
```
