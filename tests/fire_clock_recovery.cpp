#include "fire_clock_fixture.hpp"

void fire_clock_recovery() {
    fire_test_time = {}; FireClockScenario f;
    CHECK(f.send().result.code == Error::Pending); f.written(); CHECK(f.send().result.applied());
    auto records = f.s.inventory->recorded_fires();
    CHECK(records.size() == 1 && records[0].account == f.remote.account && records[0].weapon == id(104));
    auto request = *f.s.inventory->recorded_fire(f.remote.account, f.intent.fireSeq);
    auto checkpoint = Inventory(fire_catalog(), *f.s.inventory->snapshot(), f.s.inventory->epoch(), 1).checkpoint();
    checkpoint.sequence = 1;
    checkpoint.requests.push_back({f.remote.account, request.id, request.actionSeq, encode(request), {Error::Ok, 1, {}}});
    HostSession replacement(*f.s.inventory, session_info(), {14, 1}, fire_clock_now);
    auto connection = replacement.admit_authenticated(f.remote, replacement.info());
    auto restartedInput = f.intent; ++restartedInput.inputSeq; ++restartedInput.fireSeq; restartedInput.clientFireTick = 1;
    auto restartedPose = f.observation; restartedPose.authority.nowQ16 = 65536;
    f.load(); restartedPose.ammo = f.observation.ammo;
    PacketHeader header; header.messageType = MessageType::FireIntent; header.worldEpoch = replacement.info().epoch;
    CHECK(replacement.receive_fire(connection, encode_fire_packet(header, restartedInput), restartedPose).result.code == Error::SequenceMismatch);
    FireClockScenario restored(checkpoint);
    CHECK(restored.send(f.intent, {}).result.sequence == 1);
    restored.next(); // New engine clock may start from zero in a new acquired epoch.
    restored.intent.clientFireTick = 1; restored.observation.authority.nowQ16 = 65536;
    restored.load();
    CHECK(restored.send().result.code == Error::Busy);
    fire_test_time += std::chrono::milliseconds(17);
    auto oldInput = restored.intent; --oldInput.inputSeq;
    CHECK(restored.send(oldInput, restored.observation).result.code == Error::SequenceMismatch);
    CHECK(restored.send().result.code == Error::Pending); restored.written();
    CHECK(restored.send().result.sequence == 3);
    CHECK(!chamber_state(*restored.s.inventory->snapshot(), id(104)).round);
}
