#include "session_fixture.hpp"
#include "fire_scenario.hpp"
#include "client_state.hpp"

void client_fire_checks() {
    SessionScenario f; auto connection = f.join(); auto baseline = f.host.resume_state(connection);
    ClientState client(baseline, catalog()); auto shot = *shot_request(seed()).shot;
    auto intent = shot.intent; client.track_fire(intent);
    PacketHeader h; h.worldEpoch = baseline.epoch; h.messageType = MessageType::FireReceipt;
    auto accepted = make_fire_receipt(intent.fireSeq, {{Error::Ok, 1, {}}, shot}, h.worldEpoch);
    auto bytes = encode_fire_receipt(h, accepted);
    rejects([&] { client.forget_fire(intent.fireSeq); }, Error::Busy);
    auto altered = intent; ++altered.aimYaw;
    rejects([&] { client.track_fire(altered); }, Error::IdempotencyMismatch);
    client.timeout_fire(intent.fireSeq);
    auto pending = make_fire_receipt(intent.fireSeq, {{Error::Pending, 0, {}}, {}}, h.worldEpoch);
    CHECK(!client.receive_fire_receipt(encode_fire_receipt(h, pending)));
    CHECK(client.fire_status(intent.fireSeq).status == TransactionStatus::Resolving);
    client.disconnect();
    CHECK(client.retry_fire(intent.fireSeq) == intent);
    rejects([&] { client.receive_fire_receipt(bytes); }, Error::NotAccessible);
    auto wrong = baseline; ++wrong.identity.world.lo;
    rejects([&] { client.reconnect(wrong); }, Error::NotAccessible);
    client.reconnect(baseline);
    client.set_roots({id(10), id(20), id(30)});
    auto descriptor = f.host.start_snapshot(connection, f.remoteLease, f.access());
    client.begin_snapshot(descriptor);
    CHECK(client.receive_page(f.host.snapshot_page(connection, descriptor.id, 0, f.access())));
    CHECK(!client.needs_refresh());
    auto bad = accepted; ++bad.accepted->assemblyRevision;
    rejects([&] { client.receive_fire_receipt(encode_fire_receipt(h, bad)); }, Error::InvalidState);
    CHECK(client.receive_fire_receipt(bytes));
    CHECK(client.needs_refresh());
    CHECK(client.fire_status(intent.fireSeq) == accepted && !client.receive_fire_receipt(bytes));
    CHECK(!client.receive_fire_receipt(encode_fire_receipt(h, pending)));
    bad = accepted; ++bad.accepted->shotId;
    rejects([&] { client.receive_fire_receipt(encode_fire_receipt(h, bad)); }, Error::InvalidState);
    client.disconnect();
    rejects([&] { client.reconnect(baseline); }, Error::RevisionConflict);
    ++baseline.epoch; baseline.sequence = 1; client.reconnect(baseline); h.worldEpoch = baseline.epoch;
    CHECK(!client.receive_fire_receipt(encode_fire_receipt(h, accepted)));
    client.forget_fire(intent.fireSeq);
    CHECK(!client.receive_fire_receipt(encode_fire_receipt(h, accepted))); // Unknown/forgotten result cannot create effects.
    for (unsigned n = 0; n < 64; ++n) { intent.fireSeq = n; client.track_fire(intent); }
    intent.fireSeq = 64; rejects([&] { client.track_fire(intent); }, Error::Busy);
    auto rejected = make_fire_receipt(0, {{Error::NotAccessible, 0, {}}, {}}, h.worldEpoch);
    CHECK(client.receive_fire_receipt(encode_fire_receipt(h, rejected)));
    intent.fireSeq = 0; rejects([&] { client.track_fire(intent); }, Error::InvalidState);
    client.forget_fire(0); intent.fireSeq = 64; client.track_fire(intent);
}
