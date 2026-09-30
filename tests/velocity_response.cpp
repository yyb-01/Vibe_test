#include "check.hpp"
#include "velocity_response.hpp"
#include "projectile.hpp"

void velocity_response_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    const Vector incoming{300000000, -400000000, 0};
    auto energy = velocity_energy(incoming, 8000);
    CHECK(energy == 1000000000);
    const std::array scene{Barrier{{1, 1, 0}, {{1000000, -10000000, -10000000}, {1001000, 10000000, 10000000}}}};
    Projectile bullet{{{}, {300000001, -400000000, 0}}, 1, 8000};
    Atmosphere vacuum; vacuum.gravity = {};
    auto impact = advance_barriers(bullet, vacuum, scene).impact;
    CHECK(impact && impact->depositedUj == 1000000002); // Rounded speed would incorrectly give 1000000004.
    auto bounce = reflect_axis(incoming, 8000, {-1, 0, 0}, UINT16_MAX);
    CHECK((bounce.velocity == Vector{-300000000, -400000000, 0}));
    CHECK(bounce.energy.outgoingUj == energy && !bounce.energy.depositedUj);
    CHECK(reflect_axis(incoming, 8000, {0, 1, 0}, 0).velocity == Vector{});
    auto quarter = limit_energy(incoming, 8000, energy / 4);
    CHECK(quarter.velocity[0] == 150000000 && quarter.velocity[1] == -200000000);
    for (std::uint16_t keep : {0, 1, 1234, 32768, 65534, 65535}) {
        auto result = reflect_axis(incoming, 8000, {-1, 0, 0}, keep);
        CHECK(result.energy.outgoingUj <= ricochet_energy(energy, keep).outgoingUj);
        CHECK(result.energy.outgoingUj == velocity_energy(result.velocity, 8000));
        CHECK(result.energy.outgoingUj + result.energy.depositedUj == energy);
        CHECK(result.velocity[0] <= 0 && result.velocity[1] <= 0);
    }
    Vector maximum{0, 0, -2000000000};
    auto large = reflect_axis(maximum, 1000000, {0, 0, 1}, 32768);
    CHECK(large.velocity[2] > 0 && large.energy.outgoingUj <= 1000015259022LL);
    CHECK(limit_energy({1, 0, 0}, 1, 0).velocity == Vector{});
    rejects([&] { reflect_axis(incoming, 8000, {}, 1); }, Error::InvalidRequest);
    rejects([&] { reflect_axis(incoming, 8000, {-1, 1, 0}, 1); }, Error::InvalidRequest);
    rejects([&] { reflect_axis(incoming, 8000, {1, 0, 0}, 1); }, Error::InvalidRequest);
    rejects([&] { limit_energy(incoming, 8000, energy + 1); }, Error::InvalidRequest);
    rejects([&] { velocity_energy({INT64_MIN, 0, 0}, 1); }, Error::InvalidRequest);
    rejects([&] { velocity_energy({2000000000, 2000000000, 0}, 1); }, Error::InvalidRequest);
}
