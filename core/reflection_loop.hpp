#pragma once
#include "projectile.hpp"
#include "ricochet_gate.hpp"
#include "ricochet_curve.hpp"

namespace astra::ballistics {
// Authority-approved ideal axis reflection surfaces, sorted by key.
// Missing gate means preapproved ideal reflection (fixtures). Production must supply a gate.
struct ApprovedReflection {
    SurfaceKey surface; std::uint16_t keep{};
    std::optional<RicochetGate> gate{};
    std::span<const RicochetPoint> energyResponse{}; // Borrowed for this call; requires a gate.
};
struct ReflectionStep {
    Projectile state;
    std::array<BarrierImpact, 8> impacts{};
    std::uint32_t count{};
};
ReflectionStep advance_reflections(const Projectile&, const Atmosphere&, std::span<const Barrier>,
    std::span<const ApprovedReflection>, std::uint32_t duration = 1u << 24, std::uint32_t contactBudget = 8);
namespace detail {
// Applies checked 0.1mm spatial separation. Offset obstruction conservatively stops.
void leave_reflection(ReflectionStep&, const BarrierImpact&, std::span<const Barrier>, std::int64_t margin);
}
}
