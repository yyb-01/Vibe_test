#include "session_fixture.hpp"
#include "client_state.hpp"

void client_reconnect() {
    SessionScenario f; auto c = f.join();
    auto state = f.host.resume_state(c); ClientState client(state, catalog());
    CHECK(state.identity.account == f.remote.account && client.resume_action_sequence() == 1);
    auto packet = f.packet(); auto request = decode_packet(packet, state.epoch).request;
    client.track(request); auto payload = client.retry_payload(request.id);
    client.set_roots({id(10), id(20), id(30)});
    auto descriptor = f.host.start_snapshot(c, f.remoteLease, f.access());
    auto page = f.host.snapshot_page(c, descriptor.id, 0, f.access());
    client.begin_snapshot(descriptor); CHECK(client.receive_page(page));
    { std::lock_guard lock(f.s.probe->mutex); f.s.probe->hold = true; }
    CHECK(f.host.receive(c, packet, f.access()).code == Error::Pending);
    client.disconnect(); f.host.disconnect(c);
    CHECK(!client.connected() && !client.view() && client.retry_payload(request.id) == payload);
    CHECK(client.status(request.id).status == TransactionStatus::Resolving);
    rejects([&] { client.track(request); }, Error::NotAccessible);
    rejects([&] { client.receive_page(page); }, Error::NotAccessible);
    rejects([&] { f.host.resume_state(c); }, Error::NotAccessible);
    c = f.join(); auto resumed = f.host.resume_state(c);
    auto bad = resumed; ++bad.identity.account.lo;
    rejects([&] { client.reconnect(bad); }, Error::NotAccessible);
    CHECK(!client.connected()); client.reconnect(resumed);
    f.s.probe->release(); f.written();
    auto result = f.host.receive(c, packet, {});
    PacketHeader h; h.worldEpoch = resumed.epoch; h.messageType = MessageType::InventoryReceipt;
    CHECK(client.receive_receipt(encode_receipt(h, make_receipt(request.id, result, h.worldEpoch))));
    CHECK(client.status(request.id).status == TransactionStatus::Committed && f.s.probe->saves == 1);
    CHECK(f.host.resume_state(c).nextActionSequence == 2);
    CHECK(client.retry_payload(request.id) == payload);
}
