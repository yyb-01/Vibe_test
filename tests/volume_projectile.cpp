#include "check.hpp"
#include "volume_projectile.hpp"

void volume_projectile_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    constexpr std::uint32_t tick = 1u << 24;
    Flight flight{{}, {3000000, 0, 0}};
    Box box{{0, -10, -10}, {1000000, 10, 10}};
    auto volume = start_volume(flight, 1000000, box, {1000000, 0, 0}, {0, 4, 1, 1000000});
    CHECK(volume);
    VolumeProjectile input{Projectile{volume->flight, 8, 1000000}, *volume};
    auto first = advance_volume_projectile(input, tick);
    CHECK(first.state.projectile.ageSubsteps == 1 && first.state.substepFraction == 0);
    CHECK(first.state.projectile.distanceUpperUm > first.state.projectile.flight.position[0]);
    auto quarter = advance_volume_projectile(input, tick / 4);
    auto split = advance_volume_projectile(quarter.state, tick * 3 / 4);
    CHECK(split.state.projectile.flight == first.state.projectile.flight);
    CHECK(split.state.projectile.distanceUpperUm == first.state.projectile.distanceUpperUm);
    CHECK(quarter.absorbedDeltaUj + split.absorbedDeltaUj == first.absorbedDeltaUj);
    input.projectile.ageSubsteps = 1439;
    auto expired = advance_volume_projectile(input, tick);
    CHECK(expired.state.projectile.reason == StopReason::Expired && !expired.exited);
    CHECK(expired.state.projectile.flight.velocity == Vector{});
    CHECK(!advance_volume_projectile(expired.state, tick).absorbedDeltaUj);
    input.projectile.ageSubsteps = 0;
    input.projectile.distanceUpperUm = input.distanceAtEntry = 2499999900LL;
    auto ranged = advance_volume_projectile(input, tick);
    CHECK(ranged.state.projectile.reason == StopReason::Range && !ranged.exited);
    CHECK(ranged.consumed > 0 && ranged.remaining > 0 && ranged.absorbedDeltaUj > 0);
    CHECK(ranged.state.projectile.distanceUpperUm <= 2500000000LL);
    CHECK(ranged.state.projectile.flight.position[0] <= 96);
    CHECK(!advance_volume_projectile(ranged.state, tick).absorbedDeltaUj);
    CHECK(input.transit.elapsed == 0 && input.projectile.flight == volume->flight);
    auto bad = input; bad.projectile.flight.position[0] = 1;
    rejects([&] { advance_volume_projectile(bad, tick); }, Error::InvalidRequest);
    rejects([&] { advance_volume_projectile(quarter.state, tick); }, Error::InvalidRequest);
}
