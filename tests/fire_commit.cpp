#include "fire_scenario.hpp"
#include "checkpoint_delta.hpp"
#include "packet_wire.hpp"

void fire_commit_checks() {
    FireScenario s; auto before = s.inventory.snapshot(); auto request = shot_request(*before);
    auto access = approve_fire(request, shot_authority(), s.access);
    auto bytes = encode(request); CHECK(bytes.size() == 328 && encode(decode(bytes)) == bytes);
    FireScenario denied;
    CHECK(denied.inventory.apply(request, denied.access).code == Error::NotAccessible);
    CHECK(denied.inventory.snapshot()->items.at(id(100)).quantity == 1);
    FireScenario changed;
    auto tampered = request; ++tampered.shot->visualSeed;
    CHECK(changed.inventory.apply(tampered, access).code == Error::NotAccessible);
    CHECK(changed.inventory.snapshot()->items.at(id(100)).quantity == 1);
    auto wrongId = request; ++wrongId.id.lo;
    rejects([&] { encode(wrongId); }, Error::InvalidRequest);
    auto malformed = bytes; malformed[26] = 0;
    rejects([&] { decode(malformed); }, Error::InvalidRequest);
    rejects([&] { encode_packet({}, request); }, Error::InvalidRequest);
    PacketHeader header; header.worldEpoch = 1;
    auto forged = packet_wire::wrap(header, bytes, MessageType::InventoryRequest, 1200);
    rejects([&] { decode_packet(forged, 1); }, Error::InvalidRequest);
    auto prepared = s.inventory.prepare(request, access);
    CHECK(prepared.changes && prepared.changes->outcome.applied() && s.inventory.snapshot() == before);
    auto target = s.inventory.checkpoint_after(prepared.changes);
    auto encoded = encode_checkpoint(target); CHECK(encoded[4] == 3);
    auto delta = decode_delta(encode_delta(s.inventory.checkpoint_delta(prepared.changes)));
    auto patched = fire_checkpoint(); apply_checkpoint_delta(patched, delta);
    CHECK(encode_checkpoint(patched) == encoded);
    CHECK(target.world.items.at(id(100)).quantity == 0 && target.world.items.at(id(104)).durability == 65530);
    CHECK(decode(target.requests.back().payload).shot == request.shot);
    CHECK(s.inventory.abort(prepared.changes)); CHECK(s.inventory.snapshot() == before);
    CHECK(encode_checkpoint(s.inventory.checkpoint())[4] == 3);
    Inventory recovered(decode_checkpoint(encoded));
    auto result = recovered.apply(request, s.access); CHECK(result.applied() && result.sequence == 1);
    CHECK(recovered.snapshot()->items.at(id(100)).quantity == 0);
    CHECK(recovered.snapshot()->items.at(id(104)).durability == 65530);
    auto altered = request; ++altered.shot->visualSeed;
    CHECK(recovered.apply(altered, s.access).code == Error::IdempotencyMismatch);
    auto last = fire_seed();
    Inventory exhausted(fire_catalog(), last, 1, 1);
    request = shot_request(*exhausted.snapshot()); access = approve_fire(request, shot_authority(), s.access);
    CHECK(exhausted.apply(request, access).applied());
    CHECK(exhausted.snapshot()->items.at(id(100)).quantity == 0 && !exhausted.snapshot()->placements.contains(id(100)));
    last = fire_seed(); last.items.at(id(104)).durability = 4;
    Inventory worn(fire_catalog(), last, 1, 1); request = shot_request(*worn.snapshot());
    access = approve_fire(request, shot_authority(), s.access);
    CHECK(worn.apply(request, access).code == Error::NotAccessible);
    CHECK(worn.snapshot()->items.at(id(100)).quantity == 1 && worn.snapshot()->items.at(id(104)).durability == 4);
}
