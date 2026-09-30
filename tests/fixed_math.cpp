#include "check.hpp"
#include "fixed_math.hpp"
#include <array>

void fixed_math() {
    using namespace astra;
    using namespace astra::fixed;
    CHECK(mul_div(1, 1, 2) == 0 && mul_div(3, 1, 2) == 2);
    CHECK(mul_div(5, 1, 2) == 2 && mul_div(7, 1, 2) == 4);
    CHECK(mul_div(-1, 1, 2) == 0 && mul_div(-3, 1, 2) == -2);
    CHECK(mul_div(-5, 1, 2) == -2 && mul_div(7, -1, 2) == -4);
    CHECK(mul_div(INT64_MAX, INT64_MAX, INT64_MAX) == INT64_MAX);
    CHECK(mul_div(INT64_MIN, INT64_MAX, INT64_MAX) == INT64_MIN);
    CHECK(mul_div(INT64_MIN, 1, 1) == INT64_MIN);
    CHECK(mul_div(0, INT64_MIN, 1) == 0 && mul_div(INT64_MIN, 0, 1) == 0);
    CHECK(mul_div(3, 2, 4) == 2 && mul_div(-5, 2, 4) == -2);
    CHECK(mul_div(810000000000000000LL, 170, 1000000000000LL) == 137700000);
    // Expected values generated independently with JavaScript BigInt quotient/remainder.
    const std::int64_t corpus[][4]{
        {-7279715351463905374LL, 7571585457813857659LL, 9223372036854775807LL, -5976012533368902344LL},
        {4893621947923930016LL, -3991862130217141471LL, 9223372036854758030LL, -2117952529233381093LL},
        {-4442771504562355250LL, 7419905392022789431LL, 9223372036854740253LL, -3574066416328662786LL},
        {-4061996985860461652LL, -7441836440237031107LL, 9223372036854722476LL, 3277404084831615805LL},
        {6978627127725963962LL, -4786557098590791501LL, 9223372036854704699LL, -3621625267110667253LL},
        {2919158888352130168LL, 8569775917760573721LL, 9223372036854686922LL, 2712298435057796954LL}
    };
    for (const auto& row : corpus) CHECK(mul_div(row[0], row[1], row[2]) == row[3]);
    rejects([] { mul_div(INT64_MIN, INT64_MIN, INT64_MAX); }, Error::LimitExceeded);
    rejects([] { mul_div(INT64_MIN, -1, 1); }, Error::LimitExceeded);
    rejects([] { mul_div(INT64_MAX, 2, 1); }, Error::LimitExceeded);
    rejects([] { mul_div(1, 1, 0); }, Error::InvalidRequest);
    rejects([] { mul_div(0, 0, 0); }, Error::InvalidRequest);
    rejects([] { mul_div(1, 1, -1); }, Error::InvalidRequest);
    std::uint64_t seed = 19;
    for (int i = 0; i < 1000; ++i) {
        seed = seed * 6364136223846793005ULL + 1;
        auto a = static_cast<std::int64_t>((seed >> 1) | 1);
        seed = seed * 6364136223846793005ULL + 1;
        auto b = static_cast<std::int64_t>(seed >> 1);
        CHECK(mul_div(a, b, a) == b);
        CHECK(mul_div(-a, b, a) == -b);
    }
    CHECK(sqrt_nearest(0) == 0 && sqrt_nearest(2) == 1 && sqrt_nearest(3) == 2);
    CHECK(sqrt_nearest(UINT64_MAX) == (std::uint64_t{1} << 32));
    for (auto root : std::array<std::uint64_t, 6>{1, 2, 31, 65535, 2147483648ULL, UINT32_MAX}) {
        CHECK(sqrt_nearest(root * root) == root);
        CHECK(sqrt_nearest(root * root + root) == root);
        CHECK(sqrt_nearest(root * root + root + 1) == root + 1);
    }
}
