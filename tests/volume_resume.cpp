#include "check.hpp"
#include "volume_resume.hpp"

void volume_resume_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    constexpr std::uint32_t tick = 1u << 24;
    Barrier wall{{1, 1, 0}, {{0, -10, -10}, {500000, 10, 10}}};
    Flight flight{{}, {240000000, 0, 0}};
    auto volume = start_volume(flight, 8000, wall.box, {1000000, 0, 0}, {0, 0, 1, 1000000});
    CHECK(volume);
    VolumeProjectile input{Projectile{volume->flight, 8, 8000}, *volume};
    input.projectile.contacts = 1;
    auto step = advance_volume_projectile(input, tick);
    CHECK(step.exited && step.remaining == tick / 2);
    Atmosphere vacuum; vacuum.gravity = {};
    std::array scene{wall};
    auto resumed = resume_volume(step, wall.key, vacuum, scene, {}, 1);
    CHECK(resumed.state.reason == StopReason::Flying && resumed.state.ageSubsteps == 1 && !resumed.count);
    CHECK(resumed.state.flight.position[0] > 1000000 && resumed.state.flight.position[0] < 1000200);
    std::array blocked{wall, Barrier{{2, 1, 0}, {{500050, -10, -10}, {500051, 10, 10}}}};
    auto hit = resume_volume(step, wall.key, vacuum, blocked, {}, 1);
    CHECK(hit.count == 1 && hit.state.reason == StopReason::Barrier);
    CHECK(hit.impacts[0].surface.surface == 2 && hit.impacts[0].fraction == tick / 2);
    CHECK(hit.state.flight.position[0] < 500050);
    blocked[1].box.min[0] = 750000; blocked[1].box.max[0] = 750001;
    hit = resume_volume(step, wall.key, vacuum, blocked, {}, 1);
    CHECK(hit.count == 1 && hit.impacts[0].fraction > tick / 2 && hit.impacts[0].fraction < tick);
    auto unfinished = advance_volume_projectile(input, tick / 4);
    rejects([&] { resume_volume(unfinished, wall.key, vacuum, scene, {}, 1); }, Error::InvalidRequest);
    rejects([&] { resume_volume(step, {9, 9, 0}, vacuum, scene, {}, 1); }, Error::InvalidRequest);
    rejects([&] { resume_volume(step, wall.key, vacuum, scene, {}, 2); }, Error::InvalidRequest);
    CHECK(step.state.projectile.flight.position[0] == 500000 && step.state.projectile.ageSubsteps == 0);
    auto capped = step; capped.state.projectile.contacts = 7;
    hit = resume_volume(capped, wall.key, vacuum, blocked, {}, 7);
    CHECK(hit.count == 1 && hit.state.contacts == 8 && hit.state.reason == StopReason::Limit);
    blocked[1].box.min[0] = 500050; blocked[1].box.max[0] = 500051;
    hit = resume_volume(capped, wall.key, vacuum, blocked, {}, 7);
    CHECK(hit.count == 1 && hit.state.contacts == 8 && hit.state.reason == StopReason::Limit);
    blocked[1].box.min[0] = 750000; blocked[1].box.max[0] = 750001;
    auto resisted = start_volume(flight, 8000, wall.box, {1000000, 0, 0}, {0, 200, 1, 1000000});
    CHECK(resisted);
    input.transit = *resisted; input.projectile.flight = resisted->flight;
    auto slow = advance_volume_projectile(input, tick);
    CHECK(slow.exited && slow.remaining > 0);
    hit = resume_volume(slow, wall.key, vacuum, blocked, {}, 1);
    CHECK(hit.count == 1 && slow.absorbedDeltaUj + hit.impacts[0].depositedUj == 230400000);
}
