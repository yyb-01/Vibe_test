#include "check.hpp"
#include "reflection_loop.hpp"
#include "velocity_response.hpp"

void reflection_loop_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    Atmosphere vacuum; vacuum.gravity = {};
    Projectile bullet{{{}, {900000000, 0, 0}}, 7, 8000};
    std::array scene{Barrier{{1, 1, 0}, {{1000000, -1000, -1000}, {1001000, 1000, 1000}}}};
    std::array approvals{ApprovedReflection{scene[0].key, UINT16_MAX}};
    auto result = advance_reflections(bullet, vacuum, scene, approvals);
    CHECK(result.count == 1 && result.state.reason == StopReason::Flying && result.state.contacts == 1);
    CHECK(result.state.flight.velocity[0] == -900000000 && result.impacts[0].depositedUj == 0);
    CHECK(result.state.flight.position[0] < -1750000 && result.state.ageSubsteps == 1);
    auto stop = advance_reflections(bullet, vacuum, scene, {});
    CHECK(stop.count == 1 && stop.state.reason == StopReason::Barrier);
    approvals[0].keep = 32768;
    result = advance_reflections(bullet, vacuum, scene, approvals);
    CHECK(result.impacts[0].depositedUj + velocity_energy(result.state.flight.velocity, 8000) == 3240000000LL);
    CHECK(bullet.flight.position == Vector{} && bullet.contacts == 0);
    std::array corridor{Barrier{{1, 1, 0}, {{-1000, -1000, -1000}, {-900, 1000, 1000}}},
        Barrier{{2, 1, 0}, {{900, -1000, -1000}, {1000, 1000, 1000}}}};
    std::array rules{ApprovedReflection{corridor[0].key, UINT16_MAX}, ApprovedReflection{corridor[1].key, UINT16_MAX}};
    result = advance_reflections(bullet, vacuum, corridor, rules);
    CHECK(result.count == 8 && result.state.reason == StopReason::Limit && result.state.contacts == 8);
    std::int64_t sum = 0;
    for (std::uint32_t i = 0; i < result.count; ++i) {
        sum += result.impacts[i].depositedUj;
        if (i) CHECK(result.impacts[i].fraction >= result.impacts[i - 1].fraction);
    }
    CHECK(sum == 3240000000LL);
    bullet.contacts = 15;
    result = advance_reflections(bullet, vacuum, corridor, rules);
    CHECK(result.count == 1 && result.state.contacts == 16 && result.state.reason == StopReason::Limit);
    CHECK(!advance_reflections(result.state, vacuum, corridor, rules).count);
    bullet.contacts = 16;
    result = advance_reflections(bullet, vacuum, corridor, rules);
    CHECK(!result.count && result.state.reason == StopReason::Limit);
    bullet.contacts = 0; bullet.flight.velocity = {900000000, 900000000, 0};
    std::array offset{Barrier{{1, 1, 0}, {{1000000, -10000000, -1000}, {1001000, 10000000, 1000}}},
        Barrier{{2, 1, 0}, {{999950, 999996, -1000}, {999951, 999998, 1000}}}};
    approvals[0].keep = UINT16_MAX;
    result = advance_reflections(bullet, vacuum, offset, approvals);
    CHECK(result.count == 2 && result.state.reason == StopReason::Barrier);
    CHECK(result.impacts[0].surface.surface == 1 && result.impacts[1].surface.surface == 2);
    CHECK(result.impacts[0].fraction == result.impacts[1].fraction);
    CHECK(result.impacts[1].depositedUj == velocity_energy(bullet.flight.velocity, bullet.massMg));
    CHECK(result.state.flight.position[0] > 999950);
}
