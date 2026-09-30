#include "check.hpp"
#include "projectile.hpp"
#include <array>
void surface_departure_checks();

void projectile_bounds() {
    surface_departure_checks();
    using namespace astra;
    using namespace astra::ballistics;
    Projectile arc{{{}, {900000000, 0, 20431}}, 9, 8000};
    const std::array ceiling{Barrier{{1, 1, 0}, {{1800000, -1000, 15}, {1900000, 1000, 16}}}};
    auto end = free_flight(arc.flight, {});
    CHECK(end.position[2] == 0);
    CHECK(!sweep_box(arc.flight.position, end.position, ceiling[0].box));
    CHECK(advance_barriers(arc, {}, ceiling).impact); // Conservative curve envelope catches the arc.
    Atmosphere air; air.gravity = {}; air.dragPpt = 5000;
    CHECK(curve_budget(air).divisions == 8);
    auto advanced = advance_barriers(arc, air, {});
    CHECK(advanced.state.ageSubsteps == 1 && advanced.state.flight.position[0] > 0);
    CHECK(advanced.state.flight.velocity[0] < arc.flight.velocity[0]);
    air.dragPpt = 0;
    Projectile radius{{{}, {900000000, 0, 0}}, 10, 8000, 100};
    const std::array offset{Barrier{{1, 1, 0}, {{1000000, 50, -1000}, {1001000, 1000, 1000}}}};
    CHECK(!sweep_box(radius.flight.position, {3750000, 0, 0}, offset[0].box));
    CHECK(advance_barriers(radius, air, offset).impact);
    auto malformed = offset; malformed[0].box.min[1] = 8000000001LL;
    rejects([&] { advance_barriers(radius, air, malformed); }, Error::InvalidRequest);
    CHECK(radius.flight.position == Vector{} && radius.ageSubsteps == 0);
    Projectile edge{{{8000000000LL, 0, 0}, {900000000, 0, 0}}, 12, 8000};
    rejects([&] { free_flight(edge.flight, air); }, Error::LimitExceeded);
    auto stopped = advance_barriers(edge, air, {});
    CHECK(stopped.state.reason == StopReason::Limit && !stopped.impact);
    CHECK(stopped.state.flight.position == edge.flight.position && stopped.state.flight.velocity == Vector{});
    CHECK(!advance_barriers(stopped.state, air, {}).impact);
    CHECK(edge.flight.velocity[0] == 900000000);
    edge.flight.position[0] = INT64_MAX;
    rejects([&] { advance_barriers(edge, air, {}); }, Error::InvalidRequest);
    edge.flight = {{}, {0, 0, -2000000000LL}};
    CHECK(advance_barriers(edge, {}, {}).state.reason == StopReason::Limit);
}
