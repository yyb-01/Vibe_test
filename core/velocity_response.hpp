#pragma once
#include "ballistics.hpp"
#include "ballistic_energy.hpp"

namespace astra::ballistics {
struct VelocityResponse { Vector velocity; EnergyTransfer energy; };
// Uses the vector's squared norm directly: no rounded-speed sqrt in the energy ledger.
std::int64_t velocity_energy(const Vector&, std::int64_t massMg);
VelocityResponse limit_energy(const Vector&, std::int64_t massMg, std::int64_t budgetUj);
// Response only after authority approves a bounce; normal must be an incoming AABB face.
// No ricochet probability/roughness or surface offset is inferred here.
VelocityResponse reflect_axis(const Vector&, std::int64_t massMg,
    const std::array<std::int8_t, 3>& outwardNormal, std::uint16_t keepUnorm);
}
