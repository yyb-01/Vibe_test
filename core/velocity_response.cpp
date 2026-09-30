#include "velocity_response.hpp"
#include "fixed_math.hpp"
#include "error.hpp"

namespace astra::ballistics {
std::int64_t velocity_energy(const Vector& velocity, std::int64_t mass) {
    kinetic_energy(mass, 0);
    std::uint64_t squared = 0;
    for (auto axis : velocity) {
        require(axis >= -2000000000LL && axis <= 2000000000LL, Error::InvalidRequest);
        squared += static_cast<std::uint64_t>(axis * axis);
    }
    require(squared <= 4000000000000000000ULL, Error::InvalidRequest);
    return fixed::mul_div(static_cast<std::int64_t>(squared), mass, 2000000000000LL);
}
VelocityResponse limit_energy(const Vector& velocity, std::int64_t mass, std::int64_t budget) {
    auto incoming = velocity_energy(velocity, mass);
    require(budget >= 0 && budget <= incoming, Error::InvalidRequest);
    if (!budget) return {{}, {0, incoming}};
    if (budget == incoming) return {velocity, {incoming, 0}};
    constexpr std::int64_t one = std::int64_t{1} << 32;
    auto scaled = [&](std::int64_t factor) {
        Vector result{};
        for (std::size_t i = 0; i < 3; ++i) result[i] = fixed::mul_div(velocity[i], factor, one);
        return result;
    };
    // Monotone rounded component magnitudes; search the greatest safe Q0.32 factor.
    std::int64_t low = 0, high = one;
    while (high - low > 1) {
        auto mid = low + (high - low) / 2;
        if (velocity_energy(scaled(mid), mass) <= budget) low = mid; else high = mid;
    }
    auto result = scaled(low);
    auto outgoing = velocity_energy(result, mass);
    return {result, {outgoing, incoming - outgoing}};
}
VelocityResponse reflect_axis(const Vector& velocity, std::int64_t mass,
    const std::array<std::int8_t, 3>& normal, std::uint16_t keep) {
    auto incoming = velocity_energy(velocity, mass);
    std::size_t axis = 0; unsigned count = 0;
    for (std::size_t i = 0; i < 3; ++i) {
        require(normal[i] >= -1 && normal[i] <= 1, Error::InvalidRequest);
        if (normal[i]) { axis = i; ++count; }
    }
    require(count == 1 && velocity[axis] * normal[axis] < 0, Error::InvalidRequest);
    auto reflected = velocity; reflected[axis] = -reflected[axis];
    return limit_energy(reflected, mass, ricochet_energy(incoming, keep).outgoingUj);
}
}
