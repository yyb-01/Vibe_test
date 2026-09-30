#include "fire_clock_fixture.hpp"

void fire_clock_checks() {
    fire_test_time = {}; FireClockScenario f; auto first = f.intent;
    f.s.probe->hold = true;
    CHECK(f.send().result.code == Error::Pending && f.s.inventory->recorded_fires().empty());
    f.next(); CHECK(f.send().result.code == Error::Busy);
    f.s.probe->release(); f.written();
    CHECK(f.send().result.code == Error::NotAccessible); // Settles first shot; its chamber is now empty.
    CHECK(f.send(first, {}).result.applied() && f.s.inventory->snapshot()->items.at(id(100)).quantity == 0);
    f.load(); CHECK(f.send().result.code == Error::Busy);
    fire_test_time += std::chrono::nanoseconds(16666666);
    CHECK(f.send().result.code == Error::Busy);
    fire_test_time += std::chrono::nanoseconds(1);
    CHECK(f.send().result.code == Error::Pending); f.written();
    CHECK(f.send().result.sequence == 3);
    f.load();
    auto malformedOrder = f.intent; ++malformedOrder.fireSeq; --malformedOrder.inputSeq;
    CHECK(f.send(malformedOrder, f.observation).result.code == Error::SequenceMismatch);
    auto futureEngine = f.observation; futureEngine.authority.nowQ16 += 6 * 65536;
    auto third = f.intent; ++third.fireSeq; ++third.inputSeq; third.clientFireTick += 6;
    CHECK(f.send(third, futureEngine).result.code == Error::Busy); // Provider ticks cannot accelerate steady time.
    f.next(); f.intent.weaponNetId = f.observation.authority.weaponNetId = 8; f.observation.weapon = id(105);
    f.load();
    f.s.probe->aborted = true;
    CHECK(f.send().result.code == Error::Pending); f.written();
    CHECK(f.send().result.code == Error::StorageUnavailable);
    CHECK(f.s.inventory->recorded_fires().size() == 2);
    f.s.probe->aborted = false;
    CHECK(f.send().result.code == Error::Pending); f.written();
    CHECK(f.send().result.sequence == 5 && f.s.inventory->snapshot()->items.at(id(107)).quantity == 0);
    auto accepted = f.intent; f.host.disconnect(f.connection);
    f.connection = f.host.admit_authenticated(f.remote, f.host.info()); f.next();
    CHECK(f.send().result.code == Error::NotAccessible);
    CHECK(f.send(accepted, {}).result.sequence == 5);
    f.load(); CHECK(f.send().result.code == Error::Busy);
    fire_test_time += std::chrono::milliseconds(17);
    CHECK(f.send().result.code == Error::Pending); f.written(); CHECK(f.send().result.sequence == 7);
}
