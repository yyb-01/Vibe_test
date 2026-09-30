#pragma once
#include "barrier_scene.hpp"

namespace astra::ballistics {
struct CurveBudget { std::uint32_t divisions{1}; std::int64_t marginUm{}; };
CurveBudget curve_budget(const Atmosphere&);
enum class StopReason { Flying, Barrier, Expired, Range, Limit };
struct Projectile {
    Flight flight;
    std::uint64_t shotId{};
    std::int64_t massMg{}, radiusUm{};
    std::uint32_t ageSubsteps{};
    StopReason reason{StopReason::Flying};
    std::int64_t distanceUpperUm{}; // Conservative travelled-distance bound; maximum 2500m.
    std::uint16_t contacts{}; // Lifetime contact count, at most 16.
};
struct BarrierImpact {
    std::uint64_t shotId{};
    SurfaceKey surface;
    Vector position;
    std::int64_t depositedUj{};
    std::uint32_t fraction{}; // Q0.24 within this 1/240s call.
    Vector incomingVelocity{};
    std::array<std::int8_t, 3> normal{};
};
struct ProjectileStep { Projectile state; std::optional<BarrierImpact> impact; };
// Opaque static barriers: conservatively stop at first contact; no penetration or damage application.
// Four calls advance one 60Hz server tick. Returning by value keeps failures atomic.
// duration is Q0.24 of 1/240s; impact.fraction is relative to that requested duration.
ProjectileStep advance_barriers(const Projectile&, const Atmosphere&, std::span<const Barrier>,
    std::uint32_t duration = 1u << 24);
}
