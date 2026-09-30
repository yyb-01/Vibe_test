#include "session_fixture.hpp"
#include "fire_scenario.hpp"

namespace {
Checkpoint personal_world() {
    auto world = fire_seed(); auto& weapon = world.placements.at(id(104));
    weapon.container = id(10); weapon.x = weapon.y = 4;
    return Inventory(fire_catalog(), world, 1, 1).checkpoint();
}
FireObservation observed(Id account, Id pawn) {
    FireObservation result;
    result.pawn = pawn; result.inventoryRoot = id(10); result.weapon = id(104); result.ammo = id(100);
    result.authority = shot_authority(); result.authority.weaponOwner = account;
    result.launch = {{}, {900000000, 0, 0}}; result.massMg = 8000;
    result.ammoDef = 1; result.visualSeed = 9; result.durabilityCost = 5;
    return result;
}
void written(AsyncScenario& s) {
    eventually([&] { s.store->ready(); return !s.store->status().busy; });
}
}
void fire_session_checks() {
    AsyncScenario s(personal_world()); HostSession host(*s.inventory, session_info(), {14, 1}, fixed_time);
    AuthenticatedPeer remote{{77, 2}, {14, 2}};
    auto connection = host.admit_authenticated(remote, host.info());
    auto observation = observed(remote.account, remote.pawn);
    auto intent = shot_request(seed()).shot->intent;
    PacketHeader header; header.messageType = MessageType::FireIntent; header.worldEpoch = host.info().epoch;
    auto packet = encode_fire_packet(header, intent);
    CHECK(packet.size() == 66 && decode_fire_packet(packet, header.worldEpoch).intent == intent);
    auto wrong = observation; wrong.pawn = {14, 9};
    CHECK(host.receive_fire(connection, packet, wrong).result.code == Error::NotAccessible);
    wrong = observation; wrong.authority.weaponOwner = {77, 9};
    CHECK(host.receive_fire(connection, packet, wrong).result.code == Error::NotAccessible);
    wrong = observation; wrong.authority.local = true; wrong.authority.clockReady = false;
    CHECK(host.receive_fire(connection, packet, wrong).result.code == Error::NotAccessible);
    auto oldEpoch = header; ++oldEpoch.worldEpoch;
    CHECK(host.receive_fire(connection, encode_fire_packet(oldEpoch, intent), observation).result.code == Error::EpochMismatch);
    wrong = observation; wrong.ammo = id(106);
    CHECK(host.receive_fire(connection, packet, wrong).result.code == Error::NotAccessible);
    observation.authority.chambered = false; // The actual chamber position owns this cache value.
    s.probe->hold = true;
    auto pending = host.receive_fire(connection, packet, observation);
    CHECK(pending.result.code == Error::Pending && !pending.accepted);
    CHECK(s.inventory->snapshot()->items.at(id(100)).quantity == 1);
    auto original = s.inventory->recorded_fire(remote.account, intent.fireSeq);
    CHECK(original && original->moves[1].source == id(10) && original->moves[0].source == id(50));
    CHECK(!s.inventory->recorded_fire({77, 9}, intent.fireSeq));
    auto changed = intent; ++changed.aimYaw;
    CHECK(host.receive_fire(connection, encode_fire_packet(header, changed), observation).result.code == Error::IdempotencyMismatch);
    host.disconnect(connection);
    CHECK(host.receive_fire(connection, packet, observation).result.code == Error::NotAccessible);
    connection = host.admit_authenticated(remote, host.info());
    s.probe->release(); written(s);
    // The retry uses the saved launch/revisions even after current observations become unusable.
    auto accepted = host.receive_fire(connection, packet, {});
    CHECK(accepted.result.applied() && accepted.result.sequence == 1 && accepted.accepted == original->shot);
    CHECK(host.receive_fire(connection, packet, {}).accepted == accepted.accepted);
    CHECK(s.inventory->snapshot()->items.at(id(100)).quantity == 0);
    CHECK(s.inventory->snapshot()->items.at(id(104)).durability == 65530 && s.probe->saves == 1);
    auto truncated = packet; truncated.pop_back();
    CHECK(host.receive_fire(connection, truncated, observation).result.code == Error::InvalidRequest);

    AsyncScenario local(personal_world()); HostSession localHost(*local.inventory, session_info(), {14, 1}, fixed_time);
    auto localObservation = observed({77, 1}, {14, 1});
    localObservation.authority.clockReady = false;
    intent.clientFireTick = UINT32_MAX; // Host local uses authoritative now, not this client field.
    local.probe->aborted = true;
    CHECK(localHost.fire_local(intent, localObservation).result.code == Error::Pending); written(local);
    auto failed = localHost.fire_local(intent, localObservation);
    CHECK(failed.result.code == Error::StorageUnavailable && !failed.accepted);
    CHECK(local.inventory->snapshot()->items.at(id(100)).quantity == 1);
    local.probe->aborted = false;
    CHECK(localHost.fire_local(intent, localObservation).result.code == Error::Pending); written(local);
    accepted = localHost.fire_local(intent, localObservation);
    CHECK(accepted.result.applied() && accepted.accepted->effectiveQ16 == localObservation.authority.nowQ16);
    CHECK(local.inventory->snapshot()->items.at(id(100)).quantity == 0);
}
