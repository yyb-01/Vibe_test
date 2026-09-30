#include "fire_clock_fixture.hpp"

void combat_recovery() {
    fire_test_time = {}; FireClockScenario f;
    astra::ballistics::Atmosphere vacuum; vacuum.gravity = {};
    auto now = f.observation.authority.nowQ16 + 65536;
    f.s.probe->lost = true;
    CHECK(f.send().result.code == Error::Pending); f.written();
    eventually([&] { f.host.advance_combat(now, vacuum, {}); return f.host.active_shots().size() == 1; });
    auto accepted = f.send(f.intent, {});
    CHECK(accepted.result.applied() && f.s.probe->saves == 1);
    auto request = *f.s.inventory->recorded_fire(f.remote.account, f.intent.fireSeq);
    auto checkpoint = Inventory(fire_catalog(), *f.s.inventory->snapshot(), f.s.inventory->epoch(), 1).checkpoint();
    checkpoint.sequence = accepted.result.sequence;
    checkpoint.requests.push_back({f.remote.account, request.id, request.actionSeq, encode(request), accepted.result});
    FireClockScenario restarted(checkpoint);
    CHECK(restarted.host.active_shots().empty());
    auto replay = restarted.send(f.intent, {});
    CHECK(replay.result.applied() && replay.result.sequence == accepted.result.sequence && replay.accepted == accepted.accepted);
    CHECK(restarted.host.advance_combat(now, vacuum, {}).empty() && restarted.host.active_shots().empty());
    CHECK(restarted.s.probe->saves == 0);
    restarted.load(); restarted.next(); fire_test_time += std::chrono::milliseconds(17);
    CHECK(restarted.send().result.code == Error::Pending); restarted.written();
    eventually([&] { restarted.host.advance_combat(now, vacuum, {}); return restarted.host.active_shots().size() == 1; });
    CHECK(restarted.host.active_shots()[0].projectile.shotId == 3);
    CHECK(restarted.host.active_shots()[0].projectile.ageSubsteps == 0);
}
