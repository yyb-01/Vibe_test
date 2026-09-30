#include "check.hpp"
#include "ballistic_energy.hpp"
void box_penetration_checks();
void velocity_response_checks();
void penetration_transit_checks();
void transit_progress_checks();
void volume_transit_checks();
void volume_projectile_checks();
void volume_resume_checks();
void layer_path_checks();

void ballistic_energy() {
    box_penetration_checks();
    velocity_response_checks();
    penetration_transit_checks();
    transit_progress_checks();
    volume_transit_checks();
    volume_projectile_checks();
    volume_resume_checks();
    layer_path_checks();
    using namespace astra;
    using namespace astra::ballistics;
    CHECK(kinetic_energy(8000, 900000000) == 3240000000LL);
    CHECK(kinetic_energy(1000000, 2000000000LL) == 2000000000000LL);
    Resistance layer{10, 3, 1, 100};
    auto hit = penetrate(100, 20, layer);
    CHECK(hit.outgoingUj == 30 && hit.depositedUj == 70);
    auto next = penetrate(hit.outgoingUj, 20, layer);
    CHECK(next.outgoingUj == 0 && hit.depositedUj + next.depositedUj == 100);
    CHECK(penetrate(1000000, 101, layer).outgoingUj == 0);
    layer.minPathUm = 2;
    CHECK(penetrate(1000000, 1, layer).outgoingUj == 0);
    CHECK(penetrate(INT64_MAX, 2, {0, INT64_MAX, 1, 100}).outgoingUj == 0);
    CHECK(penetrate(INT64_MAX, 1, {INT64_MAX - 1, 1, 1, 100}).outgoingUj == 0);
    auto bounce = ricochet_energy(INT64_MAX, UINT16_MAX);
    CHECK(bounce.outgoingUj == INT64_MAX && bounce.depositedUj == 0);
    CHECK(ricochet_energy(123, 0).depositedUj == 123);
    for (std::int64_t energy : {0, 1, 2, 999, 3240000}) {
        for (std::uint16_t blunt : {0, 1, 32767, 32768, 65535}) {
            auto pieces = split_deposit(energy, blunt, UINT16_MAX - blunt);
            CHECK(pieces.surfaceUj >= 0 && pieces.bodyUj >= 0 && pieces.fragmentsUj >= 0);
            CHECK(pieces.surfaceUj + pieces.bodyUj + pieces.fragmentsUj == energy);
        }
    }
    rejects([] { kinetic_energy(0, 1); }, Error::InvalidRequest);
    rejects([] { kinetic_energy(1, INT64_MIN); }, Error::InvalidRequest);
    rejects([] { penetrate(1, 0, {}); }, Error::InvalidRequest);
    rejects([] { ricochet_energy(-1, 0); }, Error::InvalidRequest);
    rejects([] { split_deposit(100, UINT16_MAX, 1); }, Error::InvalidRequest);
}
