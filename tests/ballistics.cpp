#include "check.hpp"
#include "ballistics.hpp"
#include <cstdlib>

void ballistic_reference() {
    using namespace astra;
    using namespace astra::ballistics;
    Flight falling{}, moving{{}, {900000000, 0, 0}};
    Atmosphere vacuum; vacuum.gravity = {};
    for (int i = 0; i < 240; ++i) {
        falling = free_flight(falling, {});
        moving = free_flight(moving, vacuum);
    }
    CHECK(std::abs(falling.position[2] + 4903325) <= 100);
    CHECK(moving.position[0] == 900000000 && moving.velocity[0] == 900000000);
    Atmosphere air; air.gravity = {}; air.dragPpt = 170;
    Flight bullet{{}, {900000000, 0, 0}};
    constexpr auto whole = 1u << 24;
    CHECK(free_flight(bullet, air, 1, 0) == bullet);
    CHECK(free_flight(bullet, vacuum, 1, whole / 4).position[0] == 937500);
    CHECK(free_flight(bullet, vacuum, 1, 1234567).position[0] == 275947);
    for (std::uint32_t divisions : {1, 2, 4}) {
        CHECK(free_flight(bullet, air, divisions, whole / 2) == free_flight(bullet, air, divisions * 2));
        CHECK(free_flight(bullet, {}, divisions, whole / 2) == free_flight(bullet, {}, divisions * 2));
    }
    auto firstPart = free_flight(bullet, vacuum, 1, whole / 4);
    CHECK(free_flight(firstPart, vacuum, 1, whole * 3 / 4) == free_flight(bullet, vacuum));
    rejects([&] { free_flight(bullet, air, 1, whole + 1); }, Error::InvalidRequest);
    for (int i = 0; i < 240; ++i) {
        auto next = free_flight(bullet, air);
        CHECK(next.velocity[0] > 0 && next.velocity[0] < bullet.velocity[0]);
        CHECK(next.velocity[1] == 0 && next.velocity[2] == 0);
        bullet = next;
    }
    air.wind = {100000000, 0, 0};
    Flight drifting{{}, air.wind};
    CHECK(free_flight(drifting, air).velocity == drifting.velocity);
    CHECK(free_flight({}, air).velocity[0] > 0); // Moving air can add ground-frame energy.
    Flight reverse{{}, {-900000000, 0, 0}};
    air.wind = {};
    auto positive = free_flight(Flight{{}, {900000000, 0, 0}}, air);
    auto negative = free_flight(reverse, air);
    CHECK(negative.velocity[0] == -positive.velocity[0]);
    CHECK(negative.position[0] == -positive.position[0]);
    Flight invalid{{INT64_MAX, 0, 0}, {}};
    rejects([&] { free_flight(invalid, air); }, Error::InvalidRequest);
    rejects([&] { free_flight(invalid, air, 1, 0); }, Error::InvalidRequest);
    invalid = {{}, {INT64_MIN, 0, 0}};
    rejects([&] { free_flight(invalid, air); }, Error::InvalidRequest);
    invalid = {{}, {2000000000, 2000000000, 0}};
    rejects([&] { free_flight(invalid, air); }, Error::InvalidRequest);
    auto saved = reverse; air.dragPpt = UINT32_MAX;
    rejects([&] { free_flight(reverse, air); }, Error::InvalidRequest);
    CHECK(reverse == saved);
}
