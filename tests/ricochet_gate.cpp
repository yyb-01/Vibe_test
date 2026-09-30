#include "check.hpp"
#include "reflection_loop.hpp"

void ricochet_gate_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    BarrierImpact hit{17, {1, 2, 3}, {}, 0, 0, {300000000, 400000000, 0}, {-1, 0, 0}};
    RicochetGate gate{39321, 65536, true, 123};
    CHECK(!approve_ricochet(hit, 8000, 1, gate)); // mu == 0.6, strict boundary.
    ++gate.cosThreshold;
    CHECK(approve_ricochet(hit, 8000, 1, gate));
    gate.ammoAllowed = false;
    CHECK(!approve_ricochet(hit, 8000, 1, gate));
    gate.ammoAllowed = true; gate.probabilityQ16 = 0;
    CHECK(!approve_ricochet(hit, 8000, 1, gate));
    gate.probabilityQ16 = 32768;
    unsigned accepted = 0;
    for (std::uint64_t shot = 1; shot <= 64; ++shot) {
        hit.shotId = shot;
        bool first = approve_ricochet(hit, 8000, 1, gate);
        CHECK(first == approve_ricochet(hit, 8000, 1, gate));
        accepted += first;
    }
    CHECK(accepted > 0 && accepted < 64);
    rejects([&] { approve_ricochet(hit, 8000, 0, gate); }, Error::InvalidRequest);
    gate.probabilityQ16 = 65537;
    rejects([&] { approve_ricochet(hit, 8000, 1, gate); }, Error::InvalidRequest);
    gate.probabilityQ16 = 65536;
    Projectile bullet{{{}, {300000000, 400000000, 0}}, 17, 8000};
    Atmosphere vacuum; vacuum.gravity = {};
    std::array scene{Barrier{{1, 2, 3}, {{1000000, -10000000, -1000}, {1001000, 10000000, 1000}}}};
    std::array rules{ApprovedReflection{scene[0].key, UINT16_MAX, gate}};
    auto result = advance_reflections(bullet, vacuum, scene, rules);
    CHECK(result.state.reason == StopReason::Flying && result.state.flight.velocity[0] < 0);
    rules[0].gate->probabilityQ16 = 0;
    result = advance_reflections(bullet, vacuum, scene, rules);
    CHECK(result.state.reason == StopReason::Barrier && result.count == 1);
    rules[0].gate->probabilityQ16 = 65537;
    rejects([&] { advance_reflections(bullet, vacuum, {}, rules); }, Error::InvalidRequest);
}
