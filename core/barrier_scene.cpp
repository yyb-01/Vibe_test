#include "barrier_scene.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics {
std::optional<BarrierHit> first_barrier(const Vector& from, const Vector& to,
    std::span<const Barrier> scene, std::int64_t margin, SurfaceKey departing) {
    require(margin >= 0 && margin <= 101000, Error::InvalidRequest);
    require(departing == SurfaceKey{} || (departing.surface && departing.collider), Error::InvalidRequest);
    for (const auto& point : {from, to})
        for (auto axis : point) require(axis >= -8000000000LL && axis <= 8000000000LL, Error::InvalidRequest);
    std::optional<BarrierHit> best;
    SurfaceKey previous{};
    // ponytail: O(n) reference scan; use an immutable BVH before large-world deployment.
    for (const auto& barrier : scene) {
        require(barrier.key.surface && barrier.key.collider && previous < barrier.key, Error::InvalidRequest);
        previous = barrier.key;
        sweep_box(from, to, barrier.box); // Validate original bounds before conservative expansion.
        auto padded = barrier.box;
        for (std::size_t axis = 0; axis < 3; ++axis) {
            padded.min[axis] = std::max(std::int64_t{-8000000000LL}, padded.min[axis] - margin);
            padded.max[axis] = std::min(std::int64_t{8000000000LL}, padded.max[axis] + margin);
        }
        auto hit = sweep_box(from, to, padded);
        if (hit && barrier.key == departing) {
            for (std::size_t axis = 0; axis < 3; ++axis) {
                bool outward = (from[axis] == padded.min[axis] && to[axis] < from[axis]) ||
                    (from[axis] == padded.max[axis] && to[axis] > from[axis]);
                if (outward) { hit.reset(); break; }
            }
        }
        if (hit && (!best || hit->fraction < best->contact.fraction)) best = BarrierHit{barrier.key, *hit};
        // Equal Q0.24 TOIs retain the lexicographically first surface/collider/triangle.
    }
    return best;
}
}
