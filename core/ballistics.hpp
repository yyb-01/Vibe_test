#pragma once
#include <array>
#include <cstdint>

namespace astra::ballistics {
using Vector = std::array<std::int64_t, 3>;
struct Flight {
    Vector position{}, velocity{}; // micrometres, micrometres/second
    bool operator==(const Flight&) const = default;
};
struct Atmosphere {
    Vector wind{}, gravity{0, 0, -9806650};
    // Cooked rho*Cd*A/(2*m) in inverse micrometres, multiplied by 10^12.
    std::uint32_t dragPpt{};
};
// One 1/(240*divisions)s midpoint step; divisions must be 1, 2, 4 or 8.
// Validates inputs and the proposed result; failure leaves the original untouched.
// fraction is Q0.24 of that step, inclusive 0..2^24 (e.g. remaining time after impact).
Flight free_flight(const Flight&, const Atmosphere&, std::uint32_t divisions = 1,
    std::uint32_t fraction = 1u << 24);
template<std::size_t N> struct alignas(64) BulletBlock {
    std::int64_t px[N], py[N], pz[N], vx[N], vy[N], vz[N];
    std::uint64_t shotId[N];
    std::uint32_t ammoDef[N], ageSubsteps[N];
    std::uint16_t remainingContacts[N], flags[N];
};
static_assert(sizeof(BulletBlock<8>) == 576);
}
