#include "session_fixture.hpp"
#include "client_state.hpp"
#include "shutdown.hpp"
#include "stream.hpp"

namespace {
std::vector<std::uint8_t> transfer(const std::vector<std::uint8_t>& payload,
                                  std::size_t limit = datagram_limit) {
    auto wire = encode_stream(payload, limit); StreamDecoder receiver(limit);
    for (auto byte : wire) CHECK(receiver.receive(std::span(&byte, 1)) == 1);
    receiver.finish(); return receiver.take();
}
}
void stream_session() {
    SessionScenario f; auto connection = f.join(); auto state = f.host.resume_state(connection);
    PacketHeader h; h.worldEpoch = state.epoch; h.messageType = MessageType::SessionResume;
    ClientState client(decode_resume(transfer(encode_resume(h, state)), state.epoch), catalog());
    auto packet = f.packet(); auto request = decode_packet(packet, state.epoch).request;
    client.track(request); Result result;
    CHECK(f.host.receive(connection, transfer(packet), f.access()).code == Error::Pending);
    f.written(); result = f.host.receive(connection, transfer(packet), f.access());
    CHECK(result.applied());
    h.messageType = MessageType::InventoryReceipt;
    CHECK(client.receive_receipt(transfer(encode_receipt(h, make_receipt(request.id, result, state.epoch)))));
    client.set_roots({id(10), id(20), id(30)});
    auto d = f.host.start_snapshot(connection, f.remoteLease, f.access()); client.begin_snapshot(d);
    for (std::size_t n = 0; n < snapshot_pages(d); ++n)
        client.receive_page(transfer(f.host.snapshot_page(connection, d.id, n, f.access()), snapshot_page_limit));
    CHECK(client.view()->items.at(id(100)).quantity == 13 && f.s.probe->saves == 1);
    auto ready = f.host.prepare_close(); CHECK(ready.applied());
    h.messageType = MessageType::SessionClosing;
    client.receive_shutdown(transfer(encode_shutdown(h, ready.sequence)));
    CHECK(!client.connected() && !client.view());
    CHECK(client.status(request.id).status == TransactionStatus::Committed);
    eventually([&] { result = f.host.close(); return result.code != Error::Pending; });
    CHECK(result.applied());
}
