#pragma once
#include "ballistic_collision.hpp"
#include <span>

namespace astra::ballistics {
struct SurfaceKey {
    std::uint64_t surface{}, collider{}, triangle{};
    auto operator<=>(const SurfaceKey&) const = default;
};
struct Barrier { SurfaceKey key; Box box; };
struct BarrierHit { SurfaceKey key; BoxHit contact; };
// Scene sorted by unique SurfaceKey. Margin is conservative curve/radius padding.
// departing suppresses only an outward segment starting exactly on that padded face.
// It never ignores the whole collider or suppresses an inward/tangent recontact.
std::optional<BarrierHit> first_barrier(const Vector&, const Vector&,
    std::span<const Barrier>, std::int64_t marginUm, SurfaceKey departing = {});
}
