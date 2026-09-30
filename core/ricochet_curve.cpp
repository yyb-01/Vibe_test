#include "ricochet_curve.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics {
std::optional<RicochetPoint> sample_ricochet(std::span<const RicochetPoint> points, std::int64_t energy) {
    require(!points.empty() && energy >= 0, Error::InvalidRequest);
    std::int64_t previous = -1;
    for (auto point : points) {
        require(point.energyUj > previous && point.probabilityQ16 <= 65536, Error::InvalidRequest);
        previous = point.energyUj;
    }
    if (energy < points.front().energyUj || energy > points.back().energyUj) return {};
    auto high = std::lower_bound(points.begin(), points.end(), energy,
        [](auto point, auto value) { return point.energyUj < value; });
    if (high->energyUj == energy) return *high;
    auto low = high - 1;
    auto interpolate = [&](std::int64_t a, std::int64_t b) {
        return a + fixed::mul_div(b - a, energy - low->energyUj, high->energyUj - low->energyUj);
    };
    return RicochetPoint{energy,
        static_cast<std::uint32_t>(interpolate(low->probabilityQ16, high->probabilityQ16)),
        static_cast<std::uint16_t>(interpolate(low->keepUnorm, high->keepUnorm))};
}
}
