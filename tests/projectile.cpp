#include "check.hpp"
#include "projectile.hpp"
#include <array>
void reflection_loop_checks();
void ricochet_gate_checks();
void ricochet_curve_checks();

void projectile_loop() {
    reflection_loop_checks();
    ricochet_gate_checks();
    ricochet_curve_checks();
    using namespace astra;
    using namespace astra::ballistics;
    Atmosphere vacuum; vacuum.gravity = {};
    Projectile bullet{{{}, {900000000, 0, 0}}, 7, 8000};
    const std::array barriers{
        Barrier{{1, 1, 0}, {{2000000, -1000, -1000}, {2001000, 1000, 1000}}},
        Barrier{{2, 1, 0}, {{1000000, -1000, -1000}, {1001000, 1000, 1000}}}
    };
    auto result = advance_barriers(bullet, vacuum, barriers);
    CHECK(result.impact && result.impact->surface.surface == 2);
    CHECK(result.state.reason == StopReason::Barrier && result.state.flight.velocity == Vector{});
    CHECK(result.impact->depositedUj == 3240000000LL && result.impact->shotId == 7);
    CHECK(result.state.flight.position[0] <= 1000000 && result.state.flight.position[0] >= 999990);
    CHECK(!advance_barriers(result.state, vacuum, barriers).impact);
    auto tied = barriers; tied[1].box = tied[0].box;
    CHECK(advance_barriers(bullet, vacuum, tied).impact->surface.surface == 1);
    auto empty = advance_barriers(bullet, vacuum, {});
    CHECK(empty.state.flight.position[0] == 3750000 && empty.state.ageSubsteps == 1);
    bullet.ageSubsteps = 1439;
    result = advance_barriers(bullet, vacuum, {});
    CHECK(result.state.reason == StopReason::Expired && result.state.ageSubsteps == 1440);
    CHECK(advance_barriers(result.state, vacuum, {}).state.flight == result.state.flight);
    CHECK(curve_budget({}).divisions == 1);
    Atmosphere drag; drag.dragPpt = 170;
    CHECK(curve_budget(drag).divisions == 2 && curve_budget(drag).marginUm <= 1000);
    drag.dragPpt = 10000;
    rejects([&] { advance_barriers(bullet, drag, {}); }, Error::LimitExceeded);
    rejects([&] { free_flight(bullet.flight, vacuum, 3); }, Error::InvalidRequest);
    tied[1].key = tied[0].key;
    rejects([&] { advance_barriers(bullet, vacuum, tied); }, Error::InvalidRequest);
    CHECK(bullet.flight.position == Vector{} && bullet.ageSubsteps == 1439);
}
