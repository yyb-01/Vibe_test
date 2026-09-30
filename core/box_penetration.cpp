#include "box_penetration.hpp"
#include "ballistic_geometry.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <numeric>
#include <utility>

namespace astra::ballistics {
namespace {
using Wide = std::pair<std::uint64_t, std::uint64_t>; // high, low; ordered lexically.
Wide square(std::uint64_t n) { // n <= 2^35: cross product fits uint64.
    auto a = n >> 32, b = n & UINT32_MAX, cross = 2 * a * b;
    auto base = b * b, low = base + (cross << 32);
    return {a * a + (cross >> 32) + (low < base), low};
}
}
std::int64_t detail::length(const Vector& a, const Vector& b) {
    Wide sum{};
    for (std::size_t i = 0; i < 3; ++i) {
        auto d = a[i] - b[i];
        auto part = square(static_cast<std::uint64_t>(d < 0 ? -d : d));
        auto low = sum.second + part.second;
        sum.first += part.first + (low < sum.second); sum.second = low;
    }
    std::uint64_t low = 0, high = std::uint64_t{1} << 35;
    while (high - low > 1) {
        auto mid = low + (high - low) / 2;
        if (square(mid) <= sum) low = mid; else high = mid;
    }
    auto base = square(low);
    auto remainder = sum.second - base.second;
    auto upper = sum.first - base.first - (sum.second < base.second);
    return static_cast<std::int64_t>(low + (upper || remainder > low));
}
std::optional<BoxPassage> penetrate_box(const Vector& from, const Vector& to,
    const Box& box, std::int64_t incoming, const Resistance& material) {
    penetrate(incoming, material.minPathUm, material); // Validate even a miss/incomplete path.
    auto hit = sweep_box(from, to, box);
    bool inside = true, tangent = false;
    for (std::size_t i = 0; i < 3; ++i) {
        inside &= from[i] > box.min[i] && from[i] < box.max[i];
        tangent |= from[i] == to[i] && (from[i] == box.min[i] || from[i] == box.max[i]);
    }
    require(!inside, Error::InvalidRequest);
    if (!hit) return {};
    BoxPassage result{*hit, {}, {}, 0, {}};
    for (std::size_t i = 0; i < 3; ++i) {
        auto delta = to[i] - from[i];
        result.entry[i] = from[i] + fixed::mul_div(delta, hit->entryRatio[0], hit->entryRatio[1]);
        result.exit[i] = from[i] + fixed::mul_div(delta, hit->exitRatio[0], hit->exitRatio[1]);
    }
    if (!hit->exits) return result;
    result.pathUm = tangent ? 0 : detail::length(result.entry, result.exit);
    auto a = hit->entryRatio, b = hit->exitRatio;
    auto ga = std::gcd(a[0], a[1]), gb = std::gcd(b[0], b[1]);
    bool positive = a[0] / ga != b[0] / gb || a[1] / ga != b[1] / gb;
    if (!tangent && positive && !result.pathUm) result.pathUm = 1; // Never erase a sub-micrometre chord.
    result.energy = result.pathUm ? penetrate(incoming, result.pathUm, material) : EnergyTransfer{incoming, 0};
    return result;
}
}
