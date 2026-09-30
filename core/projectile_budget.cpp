#include "projectile.hpp"
#include "fixed_math.hpp"
#include "error.hpp"

namespace astra::ballistics {
CurveBudget curve_budget(const Atmosphere& air) {
    free_flight({}, air, 8); // Reuse all atmosphere bounds, including vector magnitudes.
    std::uint64_t gravitySquared = 0;
    for (auto axis : air.gravity) gravitySquared += static_cast<std::uint64_t>(axis * axis);
    auto gravity = static_cast<std::int64_t>(fixed::sqrt_nearest(gravitySquared)) + 1;
    // Global bounds: |v-w| <= 2120m/s; +2 covers integer acceleration rounding.
    auto maximum = gravity + fixed::mul_div(4494400000000000000LL, air.dragPpt, 1000000000000LL) + 2;
    for (std::uint32_t divisions = 1; divisions <= 8; divisions *= 2) {
        auto denominator = std::int64_t{8} * 240 * 240 * divisions * divisions;
        auto margin = (maximum + denominator - 1) / denominator + 2;
        if (margin <= 1000) return {divisions, margin};
    }
    throw Violation{Error::LimitExceeded}; // Cook must reject profiles exceeding eight subdivisions.
}
}
