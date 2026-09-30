#pragma once
#include "projectile.hpp"
#include "volume_transit.hpp"

namespace astra::ballistics {
struct VolumeProjectile {
    Projectile projectile; // flight must match transit while Flying; point projectile only.
    VolumeTransit transit;
    std::int64_t distanceAtEntry{};
    std::uint32_t substepFraction{}; // Already consumed Q0.24 time in the current substep.
};
struct VolumeProjectileStep {
    VolumeProjectile state;
    std::int64_t absorbedDeltaUj{};
    std::uint32_t consumed{}, remaining{};
    bool exited{};
};
// Advances at most the remaining current substep. Does not query overlapping layers or exit obstacles.
VolumeProjectileStep advance_volume_projectile(const VolumeProjectile&, std::uint32_t duration);
}
