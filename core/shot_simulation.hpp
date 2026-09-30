#pragma once
#include "reflection_loop.hpp"
#include <vector>

namespace astra {
inline constexpr std::size_t max_active_shots = 512;
struct ShotFlight {
    ballistics::Projectile projectile;
    std::uint64_t effectiveQ16{}; // Unwrapped 60Hz server time; four substeps per tick.
};
struct ShotImpact {
    ballistics::BarrierImpact impact;
    std::uint64_t substepQ16{};
    std::uint16_t contact{}; // World shotId + lifetime contact ordinal identifies this event.
};
struct ShotStep { std::vector<ShotFlight> flights; std::vector<ShotImpact> impacts; };
// Host-owned state, static scene and approved profiles; never restore these structs from client bytes.
// Returns a complete proposed batch. Failures publish neither movement nor contact events.
ShotStep advance_shots(std::span<const ShotFlight>, std::uint64_t nowQ16,
    const ballistics::Atmosphere&, std::span<const ballistics::Barrier>,
    std::span<const ballistics::ApprovedReflection> = {});
}
