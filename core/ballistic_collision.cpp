#include "ballistic_collision.hpp"
#include "ballistic_geometry.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics {
using detail::Fraction;
using detail::compare;
std::optional<BoxHit> sweep_box(const Vector& from, const Vector& to, const Box& box) {
    constexpr std::int64_t limit = 8000000000LL;
    for (std::size_t i = 0; i < 3; ++i) {
        for (auto value : {from[i], to[i], box.min[i], box.max[i]})
            require(value >= -limit && value <= limit, Error::InvalidRequest);
        require(box.min[i] < box.max[i], Error::InvalidRequest);
    }
    Fraction enter{}, leave{1, 1};
    BoxHit hit;
    for (std::size_t axis = 0; axis < 3; ++axis) {
        auto delta = to[axis] - from[axis];
        if (!delta) {
            if (from[axis] < box.min[axis] || from[axis] > box.max[axis]) return {};
            continue;
        }
        auto low = box.min[axis] - from[axis], high = box.max[axis] - from[axis];
        std::int8_t normal = -1;
        if (delta < 0) { delta = -delta; auto old = low; low = -high; high = -old; normal = 1; }
        if (high < 0 || low > delta) return {};
        Fraction near{std::max(std::int64_t{0}, low), delta};
        Fraction far{std::min(delta, high), delta};
        if (compare(near, enter) > 0 || (low == 0 && enter.n == 0 && hit.normal == BoxHit{}.normal)) {
            enter = near; hit.normal = {}; hit.normal[axis] = normal;
        }
        if (high <= delta && (compare(far, leave) < 0 ||
            (compare(far, leave) == 0 && !hit.exits))) {
            leave = far; hit.exits = true; hit.exitNormal = {};
            hit.exitNormal[axis] = static_cast<std::int8_t>(-normal);
        }
        if (compare(enter, leave) > 0) return {};
    }
    hit.fraction = static_cast<std::uint32_t>(fixed::mul_div(enter.n, 1 << 24, enter.d));
    hit.exitFraction = static_cast<std::uint32_t>(fixed::mul_div(leave.n, 1 << 24, leave.d));
    hit.entryRatio = {enter.n, enter.d}; hit.exitRatio = {leave.n, leave.d};
    return hit;
}
}
