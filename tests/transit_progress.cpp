#include "check.hpp"
#include "transit_progress.hpp"

void transit_progress_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    constexpr std::int64_t tick = 1 << 24;
    auto plan = penetration_transit({3000000, 0, 0}, 1000000, 1000000, {0, 4, 1, 1000000});
    auto half = transit_progress(plan, 1000000, 1000000, 60 * tick);
    CHECK(half.velocity[0] == 2000000 && half.travelledUm == 625000);
    CHECK(half.absorbedUj == 2500000 && !half.exited);
    std::int64_t elapsed = 0, travelled = 0, absorbed = 0, deltas = 0;
    for (int i = 0; i <= 120; ++i) {
        elapsed = i * tick;
        auto sample = transit_progress(plan, 1000000, 1000000, elapsed);
        CHECK(sample.travelledUm >= travelled && sample.absorbedUj >= absorbed);
        CHECK(sample.absorbedUj + velocity_energy(sample.velocity, 1000000) == 4500000);
        deltas += sample.absorbedUj - absorbed;
        absorbed = sample.absorbedUj; travelled = sample.travelledUm;
        if (i == 60) CHECK(sample == half);
    }
    auto end = transit_progress(plan, 1000000, 1000000, elapsed);
    CHECK(end.exited && end.travelledUm == 1000000 && deltas == 4000000);
    auto entry = penetration_transit({2000000, 0, 0}, 1000000, 1000000, {1500000, 0, 1, 1000000});
    CHECK(transit_progress(entry, 1000000, 1000000, 0).absorbedUj == 1500000);
    CHECK(transit_progress(entry, 1000000, 1000000, 120 * tick).travelledUm == 500000);
    rejects([&] { transit_progress(plan, 1000000, 1000000, -1); }, Error::InvalidRequest);
    rejects([&] { transit_progress(plan, 1000000, 1000000, elapsed + 1); }, Error::InvalidRequest);
    rejects([&] { transit_progress(plan, 1000000, 1000001, 0); }, Error::InvalidRequest);
    plan.energy.depositedUj = INT64_MAX;
    rejects([&] { transit_progress(plan, 1000000, 1000000, 0); }, Error::InvalidRequest);
}
