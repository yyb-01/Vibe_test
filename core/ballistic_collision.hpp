#pragma once
#include "ballistics.hpp"
#include <optional>

namespace astra::ballistics {
struct Box { Vector min{}, max{}; };
struct BoxHit {
    std::uint32_t fraction{}; // Q0.24: 0..2^24 inclusive, nearest-even.
    std::array<std::int8_t, 3> normal{}; // Zero when starting strictly inside.
    std::uint32_t exitFraction{1u << 24}; // Clipped to segment end; not material thickness.
    std::array<std::int8_t, 3> exitNormal{}; // Zero if no outward crossing in this segment.
    bool exits{}; // Includes an outward crossing exactly at the endpoint.
    std::array<std::int64_t, 2> entryRatio{0, 1}, exitRatio{1, 1}; // Exact n/d before TOI rounding.
};
// Continuous point segment versus static, closed AABB. Not a swept sphere/OBB query.
// Exact rational interval comparisons precede TOI quantization; no thin-wall skipping.
std::optional<BoxHit> sweep_box(const Vector& from, const Vector& to, const Box&);
}
