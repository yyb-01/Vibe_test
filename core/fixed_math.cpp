#include "fixed_math.hpp"
#include "error.hpp"
#include <limits>
#include <numeric>

namespace astra::fixed {
namespace {
std::uint64_t magnitude(std::int64_t n) {
    auto bits = static_cast<std::uint64_t>(n);
    return n < 0 ? std::uint64_t{0} - bits : bits;
}
}
std::int64_t mul_div(std::int64_t a, std::int64_t b, std::int64_t divisor) {
    require(divisor > 0, Error::InvalidRequest);
    auto x = magnitude(a), y = magnitude(b), d = static_cast<std::uint64_t>(divisor);
    if (!x || !y) return 0;
    if (y > 1) { auto common = std::gcd(y, d); y /= common; d /= common; }
    auto p0 = (x & UINT32_MAX) * (y & UINT32_MAX);
    auto p1 = (x >> 32) * (y & UINT32_MAX);
    auto p2 = (x & UINT32_MAX) * (y >> 32);
    auto middle = (p0 >> 32) + (p1 & UINT32_MAX) + (p2 & UINT32_MAX);
    auto lo = (middle << 32) | (p0 & UINT32_MAX);
    auto hi = (x >> 32) * (y >> 32) + (p1 >> 32) + (p2 >> 32) + (middle >> 32);
    require(hi < d, Error::LimitExceeded); // Otherwise the quotient cannot fit even uint64.
    std::uint64_t q = 0, r = hi;
    if (!hi) { q = lo / d; r = lo % d; }
    // ponytail: portable wide division; native ISA path only after measured need and parity tests.
    else for (int bit = 63; bit >= 0; --bit) {
        r = (r << 1) | ((lo >> bit) & 1); // r < d <= INT64_MAX, so this cannot overflow.
        if (r >= d) {
            r -= d; q |= std::uint64_t{1} << bit;
        }
    }
    bool negative = (a < 0) != (b < 0);
    auto limit = std::uint64_t(INT64_MAX) + (negative ? 1 : 0);
    require(q <= limit, Error::LimitExceeded);
    if (r > d - r || (r == d - r && (q & 1))) {
        require(q < limit, Error::LimitExceeded); ++q;
    }
    if (!negative) return static_cast<std::int64_t>(q);
    if (q == (std::uint64_t{1} << 63)) return INT64_MIN;
    return -static_cast<std::int64_t>(q);
}
std::uint64_t sqrt_nearest(std::uint64_t value) {
    auto remainder = value;
    std::uint64_t root = 0;
    for (std::uint64_t bit = std::uint64_t{1} << 62; bit; bit >>= 2) {
        if (remainder >= root + bit) {
            remainder -= root + bit; root = (root >> 1) + bit;
        } else root >>= 1;
    }
    return root + (remainder > root ? 1 : 0);
}
}
