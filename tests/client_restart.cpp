#include "scenario.hpp"
#include "client_state.hpp"

void client_restart() {
    ResumeState state{{id(90), {77,1}, {}}, 2, 5, 3};
    ClientState client(state, catalog()); Scenario s;
    auto request = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20))});
    client.track(request);
    PacketHeader h; h.worldEpoch = 2; h.messageType = MessageType::InventoryReceipt;
    auto committed = encode_receipt(h, make_receipt(request.id, {Error::Ok, 6, {}}, 2));
    client.receive_receipt(committed); client.disconnect();
    rejects([&] { client.receive_receipt(committed); }, Error::NotAccessible);
    auto next = state; next.epoch = 3; next.sequence = 6; next.nextActionSequence = 4;
    for (int n = 0; n < 5; ++n) {
        auto bad = next;
        if (n == 0) ++bad.identity.world.lo;
        if (n == 1) ++bad.identity.catalogHash[0];
        if (n == 2) bad.epoch = 1;
        if (n == 3) bad.sequence = 5;
        if (n == 4) bad.nextActionSequence = 2;
        rejects([&] { client.reconnect(bad); }, n < 2 ? Error::NotAccessible : n == 2 ? Error::EpochMismatch : Error::RevisionConflict);
        CHECK(!client.connected());
    }
    client.reconnect(next);
    CHECK(client.status(request.id).status == TransactionStatus::Committed);
    CHECK(client.status(request.id).durableWorldEpoch == 3 && client.resume_action_sequence() == 4);
    rejects([&] { client.receive_receipt(committed); }, Error::EpochMismatch);
    h.worldEpoch = 3;
    CHECK(!client.receive_receipt(encode_receipt(h, make_receipt(request.id, {Error::Pending, 0, {}}, 3))));
    CHECK(!client.receive_receipt(encode_receipt(h, make_receipt(request.id, {Error::Ok, 6, {}}, 3))));
    client.set_roots({id(10)});
    auto bytes = encode_view(s.inventory.snapshot_roots({id(10)}));
    SnapshotData data{{{3,1}, 3, 6, static_cast<std::uint32_t>(bytes.size())}, bytes};
    client.begin_snapshot(data.descriptor); CHECK(client.receive_page(encode_snapshot_page(data, 0)));
    CHECK(!client.needs_refresh());
}
