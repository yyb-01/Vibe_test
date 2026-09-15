#include "scenario.hpp"
#include "client_state.hpp"

void client_requests() {
    Scenario s; ClientState client(1, catalog());
    auto request = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20))});
    client.track(request); client.track(request);
    auto payload = client.retry_payload(request.id);
    auto bad = request; --bad.moves[0].quantity;
    rejects([&] { client.track(bad); }, Error::IdempotencyMismatch);
    client.timeout(request.id);
    CHECK(client.status(request.id).status == TransactionStatus::Resolving);
    CHECK(client.retry_payload(request.id) == payload);
    PacketHeader h; h.worldEpoch = 1; h.messageType = MessageType::InventoryReceipt;
    auto deliver = [&](Result r) { return client.receive_receipt(encode_receipt(h, make_receipt(request.id, r, 1))); };
    CHECK(!deliver({Error::Pending, 0, {}}));
    CHECK(deliver({Error::Ok, 2, {}})); CHECK(!deliver({Error::Busy, 2, {}}));
    client.timeout(request.id); CHECK(client.status(request.id).status == TransactionStatus::Committed);
    rejects([&] { deliver({Error::InvalidQuantity, 2, {}}); }, Error::InvalidState);
    CHECK(client.status(request.id).commitSequence == 2);
    client.forget(request.id); CHECK(!deliver({Error::Ok, 2, {}}));
    for (std::uint64_t n = 1; n <= 8; ++n) { request.id = {88,n}; client.track(request); }
    request.id = {88,9}; rejects([&] { client.track(request); }, Error::Busy);
    rejects([&] { client.forget({88,1}); }, Error::Busy);
    request.id = {88,1}; CHECK(deliver({Error::InvalidQuantity, 0, {}}));
    CHECK(!deliver({Error::Pending, 0, {}})); client.forget(request.id);
    request.id = {88,9}; client.track(request);
    h.worldEpoch = 2;
    auto bytes = encode_receipt(h, make_receipt(request.id, {Error::Pending, 0, {}}, 2));
    rejects([&] { client.receive_receipt(bytes); }, Error::EpochMismatch);
}
