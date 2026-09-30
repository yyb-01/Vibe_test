#pragma once
#include "barrier_scene.hpp"
#include <vector>

namespace astra::ballistics {
struct LayerVolume {
    SurfaceKey surface;
    std::uint32_t layerId{};
    std::uint64_t bodyId{}; // Zero: independent material. Nonzero: union this body's hitboxes.
    Box box;
};
struct LayerPath {
    SurfaceKey surface;
    std::uint32_t layerId{};
    std::uint64_t bodyId{};
    BoxHit contact;
    Vector entry{}, exit{};
    std::int64_t pathUm{};
    bool complete{}; // Both entry and exit known; otherwise pathUm is only the observed portion.
};
// Static straight point path, unexpanded boxes sorted by unique SurfaceKey.
// All hitboxes of one body must use one canonical tissue layerId; organs are queried separately.
// Returns Q0.24 TOI, layerId, SurfaceKey order; overlapping body intervals are unioned exactly.
std::vector<LayerPath> layer_paths(const Vector& from, const Vector& to, std::span<const LayerVolume>);
}
