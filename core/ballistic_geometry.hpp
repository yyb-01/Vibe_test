#pragma once
#include "ballistics.hpp"

namespace astra::ballistics::detail {
struct Fraction { std::int64_t n{}, d{1}; };
// Internal nonnegative ratios with positive denominators; avoids wide cross-products.
inline int compare(Fraction a, Fraction b) {
    int sign = 1;
    for (;;) {
        auto qa = a.n / a.d, qb = b.n / b.d;
        if (qa != qb) return (qa < qb ? -1 : 1) * sign;
        auto ra = a.n % a.d, rb = b.n % b.d;
        if (!ra || !rb) return (ra == rb ? 0 : !ra ? -1 : 1) * sign;
        a = {a.d, ra}; b = {b.d, rb}; sign = -sign;
    }
}
// Internal: endpoints have already been checked against the +/-8km world bounds.
std::int64_t length(const Vector&, const Vector&);
}
