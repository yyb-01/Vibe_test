#include "check.hpp"
#include "reflection_loop.hpp"
#include "velocity_response.hpp"

void ricochet_curve_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    std::array points{RicochetPoint{100, 0, 60000}, RicochetPoint{200, 65536, 10000}};
    auto midpoint = sample_ricochet(points, 150);
    CHECK(midpoint && midpoint->probabilityQ16 == 32768 && midpoint->keepUnorm == 35000);
    CHECK(sample_ricochet(points, 100)->probabilityQ16 == 0);
    CHECK(sample_ricochet(points, 200)->keepUnorm == 10000);
    CHECK(!sample_ricochet(points, 99) && !sample_ricochet(points, 201));
    points[1].energyUj = 100;
    rejects([&] { sample_ricochet(points, 99); }, Error::InvalidRequest);
    points = {RicochetPoint{0, 65536, 65535}, RicochetPoint{INT64_MAX, 0, 0}};
    auto wide = sample_ricochet(points, INT64_MAX / 2);
    CHECK(wide && wide->probabilityQ16 == 32768 && wide->keepUnorm == 32768);
    rejects([&] { sample_ricochet({}, 1); }, Error::InvalidRequest);
    Atmosphere vacuum; vacuum.gravity = {};
    Projectile bullet{{{}, {300000000, 400000000, 0}}, 17, 8000};
    std::array scene{Barrier{{1, 2, 3}, {{1000000, -10000000, -1000}, {1001000, 10000000, 1000}}}};
    std::array response{RicochetPoint{1000000000, 65536, 32768}};
    std::array rules{ApprovedReflection{scene[0].key, 0, RicochetGate{65535, 0, true, 123}, response}};
    auto result = advance_reflections(bullet, vacuum, scene, rules);
    CHECK(result.state.reason == StopReason::Flying && result.count == 1);
    CHECK(result.impacts[0].depositedUj + velocity_energy(result.state.flight.velocity, 8000) == 1000000000);
    response[0].energyUj = 1000000001;
    CHECK(advance_reflections(bullet, vacuum, scene, rules).state.reason == StopReason::Barrier);
    response[0].probabilityQ16 = 65537;
    rejects([&] { advance_reflections(bullet, vacuum, {}, rules); }, Error::InvalidRequest);
}
