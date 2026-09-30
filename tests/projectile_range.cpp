#include "check.hpp"
#include "projectile.hpp"
#include <array>

void projectile_range() {
    using namespace astra;
    using namespace astra::ballistics;
    Atmosphere vacuum; vacuum.gravity = {};
    Projectile bullet{{{}, {900000000, 0, 0}}, 11, 8000};
    bullet.distanceUpperUm = 2499500000LL;
    const std::array far{Barrier{{1, 1, 0}, {{1000000, -1000, -1000}, {1001000, 1000, 1000}}}};
    auto result = advance_barriers(bullet, vacuum, far);
    CHECK(!result.impact && result.state.reason == StopReason::Range);
    CHECK(result.state.flight.position[0] <= 500000 && result.state.flight.position[0] >= 499990);
    CHECK(result.state.distanceUpperUm <= 2500000000LL && result.state.flight.velocity == Vector{});
    CHECK(advance_barriers(result.state, vacuum, far).state.flight == result.state.flight);
    auto near = far; near[0].box.min[0] = 100000; near[0].box.max[0] = 101000;
    CHECK(advance_barriers(bullet, vacuum, near).impact);
    bullet.distanceUpperUm = 0;
    unsigned count = 0;
    while (bullet.reason == StopReason::Flying && count++ < 1440)
        bullet = advance_barriers(bullet, vacuum, {}).state;
    CHECK(bullet.reason == StopReason::Range && count < 1440);
    CHECK(bullet.flight.position[0] <= 2500000000LL && bullet.distanceUpperUm <= 2500000000LL);
    bullet.distanceUpperUm = INT64_MAX;
    rejects([&] { advance_barriers(bullet, vacuum, far); }, Error::InvalidRequest);
    rejects([&] { first_barrier({INT64_MIN, 0, 0}, {}, {}, 0); }, Error::InvalidRequest);
}
