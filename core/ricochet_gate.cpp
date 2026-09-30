#include "ricochet_gate.hpp"
#include "velocity_response.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <random>

namespace astra::ballistics {
bool approve_ricochet(const BarrierImpact& hit, std::int64_t mass, std::uint16_t contact,
    const RicochetGate& gate) {
    require(hit.shotId && hit.surface.surface && hit.surface.collider && contact && contact <= 16 &&
        gate.probabilityQ16 <= 65536, Error::InvalidRequest);
    velocity_energy(hit.incomingVelocity, mass);
    std::uint64_t squared = 0;
    std::int64_t dot = 0; unsigned axes = 0;
    for (std::size_t i = 0; i < 3; ++i) {
        require(hit.normal[i] >= -1 && hit.normal[i] <= 1, Error::InvalidRequest);
        axes += hit.normal[i] != 0;
        auto v = hit.incomingVelocity[i];
        squared += static_cast<std::uint64_t>(v * v); dot += v * hit.normal[i];
    }
    require(axes == 1, Error::InvalidRequest);
    if (!gate.ammoAllowed || dot >= 0 || !gate.probabilityQ16) return false;
    auto speed = static_cast<std::int64_t>(fixed::sqrt_nearest(squared));
    auto mu = fixed::mul_div(-dot, UINT16_MAX, speed);
    if (mu >= gate.cosThreshold) return false;
    // Standard engine outputs, no implementation-dependent uniform distribution mapping.
    std::seed_seq seed{std::uint32_t(gate.serverSeed), std::uint32_t(gate.serverSeed >> 32),
        std::uint32_t(hit.shotId), std::uint32_t(hit.shotId >> 32),
        std::uint32_t(hit.surface.surface), std::uint32_t(hit.surface.surface >> 32),
        std::uint32_t(hit.surface.collider), std::uint32_t(hit.surface.collider >> 32),
        std::uint32_t(hit.surface.triangle), std::uint32_t(hit.surface.triangle >> 32), std::uint32_t(contact)};
    std::mt19937_64 random(seed);
    return (random() >> 48) < gate.probabilityQ16;
}
}
