#include "penetration_transit.hpp"
#include "fixed_math.hpp"
#include <algorithm>

namespace astra::ballistics {
namespace {
std::int64_t speed(const Vector& velocity) {
    std::uint64_t squared = 0;
    for (auto axis : velocity) squared += static_cast<std::uint64_t>(axis * axis);
    return static_cast<std::int64_t>(fixed::sqrt_nearest(squared));
}
}
PenetrationTransit penetration_transit(const Vector& velocity, std::int64_t mass,
    std::int64_t path, const Resistance& material) {
    auto incoming = velocity_energy(velocity, mass);
    auto transfer = penetrate(incoming, path, material);
    PenetrationTransit result{{}, {}, {0, incoming}, {}};
    if (!transfer.outgoingUj) return result;
    auto entry = limit_energy(velocity, mass, incoming - material.entryUj);
    auto exit = limit_energy(entry.velocity, mass, std::min(transfer.outgoingUj, entry.energy.outgoingUj));
    if (!exit.energy.outgoingUj) return result;
    result.entryVelocity = entry.velocity; result.exitVelocity = exit.velocity;
    result.energy = {exit.energy.outgoingUj, incoming - exit.energy.outgoingUj};
    // Constant force => linear speed in time: duration = 2*path/(entrySpeed+exitSpeed).
    result.duration = fixed::mul_div(path, std::int64_t{480} * (1u << 24),
        speed(result.entryVelocity) + speed(result.exitVelocity));
    return result;
}
}
