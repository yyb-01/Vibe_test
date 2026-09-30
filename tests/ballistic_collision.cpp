#include "check.hpp"
#include "ballistic_collision.hpp"

void ballistic_collision() {
    using namespace astra;
    using namespace astra::ballistics;
    Box wall{{1000000, -1000000, -1000000}, {1001000, 1000000, 1000000}};
    auto hit = sweep_box({}, {3750000, 0, 0}, wall); // 900 m/s, 1/240s, 1mm wall.
    CHECK(hit && hit->fraction == 4473924 && hit->normal[0] == -1);
    CHECK(hit->exits && hit->exitFraction == 4478398 && hit->exitNormal[0] == 1);
    hit = sweep_box({3750000, 0, 0}, {}, wall);
    CHECK(hit && hit->normal[0] == 1);
    CHECK(hit->exits && hit->exitNormal[0] == -1);
    CHECK(!sweep_box({}, {0, 1000000, 0}, wall));
    CHECK(!sweep_box({0, 1000001, 0}, {3750000, 1000001, 0}, wall));
    CHECK(sweep_box({0, 1000000, 0}, {3750000, 1000000, 0}, wall));
    hit = sweep_box({1000001, 0, 0}, {1000001, 0, 0}, wall);
    CHECK(hit && hit->fraction == 0 && hit->normal == BoxHit{}.normal);
    CHECK(!hit->exits && hit->exitFraction == (1u << 24));
    hit = sweep_box({}, {1000000, 0, 0}, wall);
    CHECK(hit && hit->fraction == (1u << 24));
    CHECK(!hit->exits); // Merely arriving at the entry face is not an exit.
    hit = sweep_box({}, {1001000, 0, 0}, wall);
    CHECK(hit && hit->exits && hit->exitFraction == (1u << 24));
    hit = sweep_box({1000500, 0, 0}, {1000750, 0, 0}, wall);
    CHECK(hit && !hit->exits && hit->exitNormal == BoxHit{}.normal);
    hit = sweep_box({1001000, 0, 0}, {1002000, 0, 0}, wall);
    CHECK(hit && hit->exits && hit->exitFraction == 0);
    Box corner{{0, 0, 0}, {10, 10, 10}};
    hit = sweep_box({5, 5, 5}, {15, 15, 15}, corner);
    CHECK(hit && hit->exits && hit->exitFraction == (1u << 23));
    CHECK((hit->exitNormal == std::array<std::int8_t, 3>{1, 0, 0}));
    Box tiny{{0, 2, -1}, {1, 3, 1}};
    // Both axis intervals round to the same Q0.24 value but never overlap.
    CHECK(!sweep_box({-8000000000LL, -8000000000LL, 0}, {8000000000LL, 8000000000LL, 0}, tiny));
    tiny.min[1] = 0; tiny.max[1] = 1;
    CHECK(sweep_box({-8000000000LL, -8000000000LL, 0}, {8000000000LL, 8000000000LL, 0}, tiny));
    rejects([&] { sweep_box({INT64_MIN, 0, 0}, {}, wall); }, Error::InvalidRequest);
    wall.max[0] = wall.min[0];
    rejects([&] { sweep_box({}, {}, wall); }, Error::InvalidRequest);
}
