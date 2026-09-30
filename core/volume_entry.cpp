#include "volume_transit.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <cstdlib>

namespace astra::ballistics {
std::optional<VolumeTransit> start_volume(const Flight& flight, std::int64_t mass,
    const Box& box, const Vector& rayEnd, const Resistance& material) {
    auto incoming = velocity_energy(flight.velocity, mass);
    auto passage = penetrate_box(flight.position, rayEnd, box, incoming, material);
    std::size_t axis = 0;
    for (std::size_t i = 1; i < 3; ++i)
        if (std::abs(flight.velocity[i]) > std::abs(flight.velocity[axis])) axis = i;
    auto v = flight.velocity[axis], delta = rayEnd[axis] - flight.position[axis];
    require(v && delta && (v > 0) == (delta > 0), Error::InvalidRequest);
    for (std::size_t i = 0; i < 3; ++i) {
        auto expected = fixed::mul_div(flight.velocity[i], std::abs(delta), std::abs(v));
        require(std::abs(expected - (rayEnd[i] - flight.position[i])) <= 1, Error::InvalidRequest);
    }
    if (!passage || !passage->energy || !passage->pathUm) return {};
    require(passage->contact.entryRatio[0] == 0 && passage->entry == flight.position, Error::InvalidRequest);
    auto plan = penetration_transit(flight.velocity, mass, passage->pathUm, material);
    if (!plan.duration) return {};
    auto initial = transit_progress(plan, mass, passage->pathUm, 0);
    return VolumeTransit{{flight.position, initial.velocity}, passage->entry, passage->exit,
        mass, passage->pathUm, 0, initial.absorbedUj, plan};
}
}
