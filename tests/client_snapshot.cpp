#include "scenario.hpp"
#include "client_state.hpp"

void client_snapshots() {
    Scenario s; ClientState client(1, catalog()); client.set_roots({id(10)});
    auto bytes = encode_view(s.inventory.snapshot_roots({id(10)}));
    SnapshotData data{{{1,1}, 1, 0, static_cast<std::uint32_t>(bytes.size())}, bytes};
    client.begin_snapshot(data.descriptor);
    auto page = encode_snapshot_page(data, 0), corrupt = page; corrupt.back() ^= 1;
    rejects([&] { client.receive_page(corrupt); }, Error::InvalidRequest);
    CHECK(!client.view() && client.needs_refresh());
    CHECK(client.receive_page(page)); auto before = client.view();
    CHECK(before->items.size() == 4 && !client.needs_refresh());
    auto request = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20))});
    client.track(request);
    PacketHeader h; h.worldEpoch = 1; h.messageType = MessageType::InventoryReceipt;
    CHECK(client.receive_receipt(encode_receipt(h, make_receipt(request.id, {Error::Ok, 3, {}}, 1))));
    CHECK(client.needs_refresh() && client.view() == before);
    data.descriptor.id.lo = 2;
    rejects([&] { client.begin_snapshot(data.descriptor); }, Error::RevisionConflict);
    data.descriptor.sequence = 3; client.begin_snapshot(data.descriptor);
    CHECK(client.receive_page(encode_snapshot_page(data, 0)) && !client.needs_refresh());
    before = client.view();
    data.descriptor.id.lo = 3; data.bytes = encode_view(s.inventory.snapshot_roots({id(20)}));
    data.descriptor.bytes = data.bytes.size(); client.begin_snapshot(data.descriptor);
    rejects([&] { client.receive_page(encode_snapshot_page(data, 0)); }, Error::NotAccessible);
    CHECK(client.view() == before);
    client.set_roots({}); CHECK(!client.view());
    rejects([&] { client.begin_snapshot(data.descriptor); }, Error::NotAccessible);
    client.set_roots({id(20)}); data.descriptor.id.lo = 4; client.begin_snapshot(data.descriptor);
    CHECK(client.receive_page(encode_snapshot_page(data, 0)));
    data.descriptor.id.lo = 3;
    rejects([&] { client.begin_snapshot(data.descriptor); }, Error::RevisionConflict);
}
