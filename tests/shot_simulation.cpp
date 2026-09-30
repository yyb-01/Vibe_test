#include "check.hpp"
#include "shot_simulation.hpp"

void shot_simulation() {
    using namespace astra;
    using namespace astra::ballistics;
    Atmosphere vacuum; vacuum.gravity = {};
    constexpr std::uint64_t launch = 100 * 65536;
    std::array flights{
        ShotFlight{{{{}, {900000000, 0, 0}}, 1, 8000}, launch},
        ShotFlight{{{{2000000, 0, 0}, {900000000, 0, 0}}, 2, 8000}, launch}
    };
    const std::array wall{Barrier{{1, 1, 0}, {{10000000, -1000, -1000}, {10001000, 1000, 1000}}}};
    auto hit = advance_shots(flights, launch + 65536, vacuum, wall);
    CHECK(hit.flights.empty() && hit.impacts.size() == 2);
    CHECK(hit.impacts[0].impact.shotId == 2 && hit.impacts[1].impact.shotId == 1);
    CHECK(hit.impacts[0].contact == 1 && hit.impacts[1].contact == 1);
    CHECK(hit.impacts[0].impact.depositedUj == 3240000000LL);
    CHECK(flights[0].projectile.ageSubsteps == 0 && flights[0].projectile.flight.position == Vector{});
    auto full = advance_shots(flights, launch + 65536, vacuum, {});
    auto half = advance_shots(flights, launch + 32768, vacuum, {});
    auto split = advance_shots(half.flights, launch + 65536, vacuum, {});
    CHECK(full.flights.size() == 2 && full.impacts.empty());
    CHECK(full.flights[0].projectile.flight == split.flights[0].projectile.flight);
    CHECK(full.flights[0].projectile.ageSubsteps == 4);
    rejects([&] { advance_shots(half.flights, launch, vacuum, {}); }, Error::InvalidRequest);
    rejects([&] { advance_shots(flights, launch - 1, vacuum, {}); }, Error::InvalidRequest);
    auto duplicate = flights; duplicate[1].projectile.shotId = 1;
    rejects([&] { advance_shots(duplicate, launch + 65536, vacuum, wall); }, Error::InvalidRequest);
    const std::array unapproved{ApprovedReflection{{1, 1, 0}, 65535}};
    rejects([&] { advance_shots({}, launch, vacuum, wall, unapproved); }, Error::InvalidRequest);
    auto invalid = vacuum; invalid.wind[0] = 120000001;
    rejects([&] { advance_shots({}, launch, invalid, {}); }, Error::InvalidRequest);
    std::vector<ShotFlight> excess(max_active_shots + 1);
    rejects([&] { advance_shots(excess, launch, vacuum, {}); }, Error::LimitExceeded);
    flights[0].projectile.flight.velocity = {1000000, 0, 0};
    CHECK(advance_shots(std::span(flights).first(1), UINT64_MAX, vacuum, {}).flights.empty());
}
