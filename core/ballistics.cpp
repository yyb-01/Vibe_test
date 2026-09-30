#include "ballistics.hpp"
#include "fixed_math.hpp"
#include "error.hpp"

namespace astra::ballistics {
namespace {
void components(const Vector& v, std::int64_t limit, Error error = Error::InvalidRequest) {
    for (auto value : v) require(value >= -limit && value <= limit, error);
}
std::uint64_t square_length(const Vector& v) {
    std::uint64_t result = 0;
    for (auto value : v) result += static_cast<std::uint64_t>(value * value);
    return result; // Called only after the component bounds below.
}
void speed(const Vector& v, std::int64_t limit, Error error = Error::InvalidRequest) {
    components(v, limit, error);
    require(square_length(v) <= static_cast<std::uint64_t>(limit * limit), error);
}
Vector acceleration(const Vector& velocity, const Atmosphere& air) {
    Vector relative{}, result{};
    for (std::size_t i = 0; i < 3; ++i) relative[i] = velocity[i] - air.wind[i];
    auto length = static_cast<std::int64_t>(fixed::sqrt_nearest(square_length(relative)));
    for (std::size_t i = 0; i < 3; ++i)
        result[i] = air.gravity[i] - fixed::mul_div(length * relative[i], air.dragPpt, 1000000000000LL);
    return result;
}
}
Flight free_flight(const Flight& input, const Atmosphere& air, std::uint32_t divisions, std::uint32_t fraction) {
    require(divisions == 1 || divisions == 2 || divisions == 4 || divisions == 8, Error::InvalidRequest);
    require(fraction <= (1u << 24), Error::InvalidRequest);
    auto rate = std::int64_t{240} * divisions * (1u << 24);
    if (fraction == (1u << 24)) { fraction = 1; rate /= (1u << 24); }
    components(input.position, 8000000000LL);
    speed(input.velocity, 2000000000LL); speed(air.wind, 120000000LL);
    speed(air.gravity, 100000000LL);
    require(air.dragPpt <= 10000, Error::InvalidRequest);
    if (!fraction) return input;
    auto first = acceleration(input.velocity, air);
    Vector midpoint{};
    for (std::size_t i = 0; i < 3; ++i)
        midpoint[i] = input.velocity[i] + fixed::mul_div(first[i], fraction, rate * 2);
    speed(midpoint, 2000000000LL, Error::LimitExceeded);
    auto middle = acceleration(midpoint, air);
    auto result = input;
    for (std::size_t i = 0; i < 3; ++i) {
        result.position[i] += fixed::mul_div(midpoint[i], fraction, rate);
        result.velocity[i] += fixed::mul_div(middle[i], fraction, rate);
    }
    components(result.position, 8000000000LL, Error::LimitExceeded);
    speed(result.velocity, 2000000000LL, Error::LimitExceeded);
    return result;
}
}
