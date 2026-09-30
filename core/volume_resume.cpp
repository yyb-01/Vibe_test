#include "volume_resume.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics {
ReflectionStep resume_volume(const VolumeProjectileStep& input, SurfaceKey surface, const Atmosphere& air,
    std::span<const Barrier> scene, std::span<const ApprovedReflection> approvals, std::uint32_t priorContacts) {
    require(input.exited && priorContacts <= 8 && priorContacts <= input.state.projectile.contacts, Error::InvalidRequest);
    auto checked = advance_volume_projectile(input.state, 0);
    ReflectionStep result{checked.state.projectile};
    if (result.state.reason != StopReason::Flying) return result;
    require(checked.exited && input.remaining == (input.state.substepFraction ?
        (1u << 24) - input.state.substepFraction : 0), Error::InvalidRequest);
    if (priorContacts == 8) {
        result.state.reason = StopReason::Limit; result.state.flight.velocity = {}; return result;
    }
    auto position = result.state.flight.position;
    first_barrier(position, position, scene, 0); // Validate every scene key/bounds before lookup.
    auto wall = std::find_if(scene.begin(), scene.end(), [&](auto b) { return b.key == surface; });
    require(wall != scene.end(), Error::InvalidRequest);
    std::array<std::int8_t, 3> normal{};
    for (std::size_t i = 0; i < 3; ++i) {
        require(position[i] >= wall->box.min[i] && position[i] <= wall->box.max[i], Error::InvalidRequest);
        if (normal == std::array<std::int8_t, 3>{}) {
            if (position[i] == wall->box.min[i] && result.state.flight.velocity[i] < 0) normal[i] = -1;
            if (position[i] == wall->box.max[i] && result.state.flight.velocity[i] > 0) normal[i] = 1;
        }
    }
    require(normal != std::array<std::int8_t, 3>{}, Error::InvalidRequest);
    auto time = input.remaining ? input.state.substepFraction : 1u << 24;
    BarrierImpact exit{result.state.shotId, surface, position, 0, time, result.state.flight.velocity, normal};
    detail::leave_reflection(result, exit, scene, curve_budget(air).marginUm);
    if (result.count + priorContacts == 8) result.state.reason = StopReason::Limit;
    if (result.state.reason != StopReason::Flying || !input.remaining) return result;
    return advance_reflections(result.state, air, scene, approvals, input.remaining, 8 - priorContacts);
}
}
