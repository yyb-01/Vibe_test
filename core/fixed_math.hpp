#pragma once
#include <cstdint>

namespace astra::fixed {
// Exact signed 128-bit product, then nearest integer division; ties go to even.
// Positive divisor only. Overflow and zero divisor throw Violation.
std::int64_t mul_div(std::int64_t a, std::int64_t b, std::int64_t divisor);
// Nearest integer square root of an unsigned 64-bit value, without libm.
std::uint64_t sqrt_nearest(std::uint64_t value);
}
