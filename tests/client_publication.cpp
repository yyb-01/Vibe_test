#include "scenario.hpp"
#include "client_state.hpp"

void client_publication() {
    World world; std::set<Id> roots;
    for (std::uint64_t n = 10; n < 13; ++n) {
        auto c = container(n); c.state.width = c.state.height = 32;
        world.containers.emplace(id(n), c); roots.insert(id(n));
        for (unsigned item = 0; item < 250; ++item)
            add_item(world, n * 1000 + item, 1, 1, n, item % 32, item / 32);
    }
    Inventory inventory(catalog(), std::move(world), 1, 2);
    auto bytes = encode_view(inventory.snapshot_roots(roots));
    SnapshotData data{{{1,1}, 1, 0, static_cast<std::uint32_t>(bytes.size())}, bytes};
    CHECK(snapshot_pages(data.descriptor) == 2);
    ClientState client(1, catalog()); client.set_roots(roots); client.begin_snapshot(data.descriptor);
    CHECK(!client.receive_page(encode_snapshot_page(data, 1)) && !client.view());
    client.begin_snapshot(data.descriptor); // Repeated control message preserves received pages.
    CHECK(client.receive_page(encode_snapshot_page(data, 0)));
    auto old = client.view(); CHECK(old->items.size() == 750);
    data.descriptor.id.lo = 2; data.descriptor.sequence = 1;
    client.begin_snapshot(data.descriptor);
    CHECK(!client.receive_page(encode_snapshot_page(data, 0)) && client.view() == old);
    // A newer durable ACK cancels the now-obsolete partial transfer.
    Request request{{88,1}, 1, Operation::Move, {move(*old, id(10000), id(11))}, 0, 99};
    client.track(request); PacketHeader h; h.worldEpoch = 1; h.messageType = MessageType::InventoryReceipt;
    client.receive_receipt(encode_receipt(h, make_receipt(request.id, {Error::Ok, 2, {}}, 1)));
    rejects([&] { client.receive_page(encode_snapshot_page(data, 1)); }, Error::InvalidState);
    CHECK(client.view() == old && client.needs_refresh());
    data.descriptor.id.lo = 3; data.descriptor.sequence = 2;
    // Valid page checksums with semantically invalid quantity must not replace the view.
    data.bytes[20 + 16 * roots.size() + 28] = 0;
    client.begin_snapshot(data.descriptor);
    CHECK(!client.receive_page(encode_snapshot_page(data, 0)));
    rejects([&] { client.receive_page(encode_snapshot_page(data, 1)); }, Error::InvalidQuantity);
    CHECK(client.view() == old && client.sequence() == 0);
    client.set_roots({}); CHECK(!client.view() && !client.needs_refresh());
}
