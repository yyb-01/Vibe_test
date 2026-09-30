#include "check.hpp"
#include "box_penetration.hpp"

void box_penetration_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    Box box{{0, -10, -10}, {1, 10, 10}};
    Resistance material{10, 3, 1, 100};
    auto hit = penetrate_box({-8000000000LL, 0, 0}, {8000000000LL, 0, 0}, box, 100, material);
    CHECK(hit && hit->contact.fraction == hit->contact.exitFraction);
    CHECK(hit->pathUm == 1 && hit->energy->outgoingUj == 87); // Sub-Q0.24 wall retained.
    auto reverse = penetrate_box({8000000000LL, 0, 0}, {-8000000000LL, 0, 0}, box, 100, material);
    CHECK(reverse && reverse->pathUm == 1 && reverse->energy->depositedUj == 13);
    box.max[0] = 100;
    hit = penetrate_box({-1, 0, 0}, {50, 0, 0}, box, 100, material);
    CHECK(hit && !hit->energy && !hit->contact.exits);
    hit = penetrate_box({-1, 0, 0}, {100, 0, 0}, box, 100, material);
    CHECK(hit && hit->pathUm == 100 && hit->energy->outgoingUj == 0);
    hit = penetrate_box({-1, 10, 0}, {101, 10, 0}, box, 100, material);
    CHECK(hit && hit->pathUm == 0 && hit->energy->outgoingUj == 100);
    box = {{0, 0, -10}, {300, 400, 10}};
    hit = penetrate_box({0, 0, 0}, {300, 400, 0}, box, 10000, material);
    CHECK(hit && hit->pathUm == 500 && hit->energy->outgoingUj == 0); // No maxPath clipping.
    box = {{-8000000000LL, -8000000000LL, -8000000000LL}, {8000000000LL, 8000000000LL, 8000000000LL}};
    hit = penetrate_box(box.min, box.max, box, INT64_MAX, {0, 1, 1, INT64_MAX});
    CHECK(hit && hit->pathUm == 27712812921LL);
    CHECK(hit->energy->depositedUj + hit->energy->outgoingUj == INT64_MAX);
    for (std::int64_t scale : {1, 99, 500000000}) {
        Box diagonal{{}, {3 * scale, 4 * scale, 12 * scale}};
        auto path = penetrate_box({}, diagonal.max, diagonal, INT64_MAX, {0, 1, 1, INT64_MAX});
        CHECK(path && path->pathUm == 13 * scale);
    }
    Box tiny{{0, 0, -1}, {1, 1, 1}};
    auto sub = penetrate_box({-1, 1, 0}, {3, -2, 0}, tiny, 100, material);
    CHECK(sub && sub->pathUm == 1 && sub->energy->depositedUj == 13);
    sub = penetrate_box({-1, 1, 0}, {1, -1, 0}, tiny, 100, material);
    CHECK(sub && sub->pathUm == 0 && sub->energy->depositedUj == 0);
    rejects([&] { penetrate_box({}, box.max, box, 100, material); }, Error::InvalidRequest);
    rejects([&] { penetrate_box(box.min, box.max, box, -1, material); }, Error::InvalidRequest);
}
