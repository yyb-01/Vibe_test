#include "session_fixture.hpp"
#include "receipt.hpp"
#include "client_state.hpp"

void session_receipts() {
    SessionScenario f; auto c = f.join(); auto bytes = f.packet();
    auto request = decode_packet(bytes, f.host.info().epoch).request;
    ClientState client(f.host.info().epoch, catalog()); client.track(request);
    PacketHeader header; header.worldEpoch = f.host.info().epoch;
    header.messageType = MessageType::InventoryReceipt;
    auto receive = [&] {
        auto result = f.host.receive(c, bytes, f.access());
        auto reply = encode_receipt(header, make_receipt(request.id, result, header.worldEpoch));
        client.receive_receipt(reply);
        return decode_receipt(reply, header.worldEpoch).receipt;
    };
    { std::lock_guard lock(f.s.probe->mutex); f.s.probe->hold = true; }
    auto pending = receive();
    CHECK(pending.status == TransactionStatus::Pending && pending.commitSequence == 0);
    CHECK(f.s.inventory->snapshot()->items.at(id(100)).quantity == 20);
    client.timeout(request.id);
    f.host.revoke_lease(c);
    CHECK(receive().status == TransactionStatus::Pending);
    f.s.probe->release(); f.written();
    auto committed = receive();
    CHECK(committed.status == TransactionStatus::Committed && committed.commitSequence == 1);
    CHECK(receive() == committed && f.s.probe->saves == 1);
    // Replayed ACKs are still rate limited; Busy cannot retract the commit.
    TransactionReceipt busy;
    for (int n = 0; n < 20; ++n) busy = receive();
    CHECK(busy.status == TransactionStatus::Resolving && busy.reason == ClientReason::Busy);
    CHECK(client.status(request.id).status == TransactionStatus::Committed);
    CHECK(f.s.inventory->snapshot()->items.at(id(100)).quantity == 13 && f.s.probe->saves == 1);
}
