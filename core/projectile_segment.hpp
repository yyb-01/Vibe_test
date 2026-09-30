#pragma once
#include "ballistics.hpp"
#include "fixed_math.hpp"

namespace astra::ballistics::detail {
// Inputs come from validated bounded flight states.
inline Flight blend(const Flight& from, const Flight& to, std::uint32_t fraction) {
    auto result = from;
    for (std::size_t axis = 0; axis < 3; ++axis) {
        result.position[axis] += fixed::mul_div(to.position[axis] - from.position[axis], fraction, 1 << 24);
        result.velocity[axis] += fixed::mul_div(to.velocity[axis] - from.velocity[axis], fraction, 1 << 24);
    }
    return result;
}
inline std::int64_t distance_bound(const Flight& from, const Flight& to, std::int64_t curveMargin) {
    std::uint64_t squared = 0;
    for (std::size_t axis = 0; axis < 3; ++axis) {
        auto delta = to.position[axis] - from.position[axis];
        squared += static_cast<std::uint64_t>(delta * delta);
    }
    auto length = fixed::sqrt_nearest(squared);
    if (length * length < squared) ++length;
    // |v(t)-mean(v)| <= a_max*h/2: chord + a_max*h*h/2 bounds travelled length.
    return static_cast<std::int64_t>(length) + 4 * curveMargin;
}
}
