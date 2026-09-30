#include "fire_clock_fixture.hpp"

void combat_publication() {
    using namespace astra::ballistics;
    fire_test_time = {}; FireClockScenario f;
    Atmosphere vacuum; vacuum.gravity = {};
    auto now = f.observation.authority.nowQ16 + 65536;
    f.s.probe->hold = true;
    CHECK(f.send().result.code == Error::Pending && f.host.active_shots().empty());
    CHECK(f.host.advance_combat(now, vacuum, {}).empty() && f.host.active_shots().empty());
    f.host.disconnect(f.connection);
    f.s.probe->release(); f.written();
    eventually([&] { f.host.advance_combat(now, vacuum, {}); return f.host.active_shots().size() == 1; });
    const auto& bullet = f.host.active_shots()[0].projectile;
    CHECK(bullet.shotId == 1 && bullet.ageSubsteps == 4 && bullet.flight.position[0] == 15000000);
    f.connection = f.host.admit_authenticated(f.remote, f.host.info());
    CHECK(f.send(f.intent, {}).result.sequence == 1 && f.s.probe->saves == 1);
    CHECK(f.host.advance_combat(now, vacuum, {}).empty());
    CHECK(f.host.active_shots()[0].projectile.ageSubsteps == 4);
    rejects([&] { f.host.advance_combat(now - 1, vacuum, {}); }, Error::InvalidRequest);
    CHECK(f.host.active_shots()[0].projectile.flight.position[0] == 15000000);
    const std::array wall{Barrier{{1, 1, 0}, {{20000000, -1000, -1000}, {20001000, 1000, 1000}}}};
    auto events = f.host.advance_combat(now + 65536, vacuum, wall);
    CHECK(events.size() == 1 && f.host.active_shots().empty());
    CHECK(events[0].impact.shotId == 1 && events[0].contact == 1);
    CHECK(events[0].impact.depositedUj == 3240000000LL);
    CHECK(f.send(f.intent, {}).result.sequence == 1 && f.host.active_shots().empty());
    CHECK(f.host.advance_combat(now + 65536, vacuum, wall).empty());
}
void combat_failure() {
    fire_test_time = {}; FireClockScenario f;
    astra::ballistics::Atmosphere vacuum; vacuum.gravity = {};
    auto now = f.observation.authority.nowQ16 + 65536;
    f.s.probe->aborted = true;
    CHECK(f.send().result.code == Error::Pending); f.written();
    CHECK(f.host.advance_combat(now, vacuum, {}).empty() && f.host.active_shots().empty());
    CHECK(f.send().result.code == Error::StorageUnavailable); // Tick retains the failure for this retry.
    CHECK(f.s.inventory->snapshot()->items.at(id(100)).quantity == 1);
    f.s.probe->aborted = false;
    CHECK(f.send().result.code == Error::Pending); f.written();
    eventually([&] { f.host.advance_combat(now, vacuum, {}); return !f.host.active_shots().empty(); });
    CHECK(f.send(f.intent, {}).result.applied() && f.s.probe->saves == 2);
}
