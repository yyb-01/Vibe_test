#include "layer_paths.hpp"
#include "ballistic_geometry.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <algorithm>
#include <tuple>

namespace astra::ballistics {
std::vector<LayerPath> layer_paths(const Vector& from, const Vector& to, std::span<const LayerVolume> scene) {
    auto compare = [](auto a, auto b) { return detail::compare({a[0], a[1]}, {b[0], b[1]}); };
    for (auto point : {from, to}) for (auto axis : point)
        require(axis >= -8000000000LL && axis <= 8000000000LL, Error::InvalidRequest);
    std::vector<LayerPath> paths;
    SurfaceKey previous{};
    for (const auto& layer : scene) {
        require(layer.surface.surface && layer.surface.collider && previous < layer.surface && layer.layerId,
            Error::InvalidRequest);
        previous = layer.surface;
        // ponytail: O(n^2) metadata validation; move it to cook time before a BVH hot path.
        if (layer.bodyId) for (const auto& other : scene)
            require(other.bodyId != layer.bodyId || other.layerId == layer.layerId, Error::InvalidRequest);
        auto hit = sweep_box(from, to, layer.box);
        bool tangent = false;
        for (std::size_t i = 0; i < 3; ++i)
            tangent |= from[i] == to[i] && (from[i] == layer.box.min[i] || from[i] == layer.box.max[i]);
        if (!hit || tangent || from == to || compare(hit->entryRatio, hit->exitRatio) == 0) continue;
        paths.push_back({layer.surface, layer.layerId, layer.bodyId, *hit});
    }
    std::sort(paths.begin(), paths.end(), [&](const auto& a, const auto& b) {
        if (a.bodyId != b.bodyId) return a.bodyId < b.bodyId;
        auto order = compare(a.contact.entryRatio, b.contact.entryRatio);
        return order ? order < 0 : a.surface < b.surface;
    });
    std::vector<LayerPath> result;
    for (auto path : paths) {
        if (!result.empty() && path.bodyId && path.bodyId == result.back().bodyId &&
            compare(path.contact.entryRatio, result.back().contact.exitRatio) <= 0) {
            auto& end = result.back().contact;
            if (!compare(path.contact.entryRatio, end.entryRatio) &&
                path.contact.normal == std::array<std::int8_t, 3>{}) end.normal = {};
            auto order = compare(path.contact.exitRatio, end.exitRatio);
            if (order > 0) {
                end.exitRatio = path.contact.exitRatio; end.exitFraction = path.contact.exitFraction;
                end.exitNormal = path.contact.exitNormal; end.exits = path.contact.exits;
            } else if (!order) end.exits &= path.contact.exits;
        } else result.push_back(path);
    }
    for (auto& path : result) {
        for (std::size_t i = 0; i < 3; ++i) {
            auto delta = to[i] - from[i];
            auto a = path.contact.entryRatio, b = path.contact.exitRatio;
            path.entry[i] = from[i] + fixed::mul_div(delta, a[0], a[1]);
            path.exit[i] = from[i] + fixed::mul_div(delta, b[0], b[1]);
        }
        path.pathUm = std::max(std::int64_t{1}, detail::length(path.entry, path.exit));
        path.complete = path.contact.exits && path.contact.normal != std::array<std::int8_t, 3>{};
    }
    std::sort(result.begin(), result.end(), [](const auto& a, const auto& b) {
        return std::tie(a.contact.fraction, a.layerId, a.surface) < std::tie(b.contact.fraction, b.layerId, b.surface);
    });
    return result;
}
}
