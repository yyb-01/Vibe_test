#pragma once
#include "volume_projectile.hpp"
#include "reflection_loop.hpp"

namespace astra::ballistics {
// Resume only after an exited volume step that was given all remaining current-substep time.
// priorContacts includes all contacts already consumed in this substep, including volume entry.
// The caller applies the volume step's absorbedDeltaUj separately, once.
ReflectionStep resume_volume(const VolumeProjectileStep&, SurfaceKey exitedSurface,
    const Atmosphere&, std::span<const Barrier>, std::span<const ApprovedReflection>, std::uint32_t priorContacts);
}
