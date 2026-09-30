#include "check.hpp"
#include "penetration_transit.hpp"

void penetration_transit_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    constexpr std::int64_t tick = 1 << 24;
    Resistance material{0, 0, 1, 1000000};
    auto straight = penetration_transit({2000000, 0, 0}, 1000000, 1000000, material);
    CHECK(straight.duration == 120 * tick && straight.energy.depositedUj == 0);
    material.entryUj = 1500000;
    auto entry = penetration_transit({2000000, 0, 0}, 1000000, 1000000, material);
    CHECK(entry.entryVelocity[0] == 1000000 && entry.exitVelocity[0] == 1000000);
    CHECK(entry.duration == 240 * tick && entry.energy.depositedUj == 1500000);
    material = {0, 4, 1, 1000000};
    auto slowing = penetration_transit({3000000, 0, 0}, 1000000, 1000000, material);
    CHECK(slowing.duration == 120 * tick && slowing.exitVelocity[0] == 1000000);
    CHECK(slowing.energy.depositedUj == 4000000 && slowing.energy.outgoingUj == 500000);
    auto reverse = penetration_transit({-3000000, 0, 0}, 1000000, 1000000, material);
    CHECK(reverse.duration == slowing.duration && reverse.exitVelocity[0] == -1000000);
    auto stopped = penetration_transit({1000000, 0, 0}, 1000000, 1000000, material);
    CHECK(!stopped.duration && stopped.exitVelocity == Vector{} && stopped.energy.depositedUj == 500000);
    stopped = penetration_transit({3000000, 0, 0}, 1000000, 1000001, material);
    CHECK(!stopped.duration && stopped.energy.outgoingUj == 0); // Never shorten calibration overflow.
    auto thin = penetration_transit({2000000000, 0, 0}, 1, 1, {0, 0, 1, 1});
    CHECK(thin.duration && *thin.duration > 0);
    rejects([&] { penetration_transit({}, 1, 0, material); }, Error::InvalidRequest);
    rejects([&] { penetration_transit({INT64_MIN, 0, 0}, 1, 1, material); }, Error::InvalidRequest);
}
