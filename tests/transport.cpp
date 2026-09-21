#include "session_fixture.hpp"
#include "client_state.hpp"
#include "transport.hpp"

namespace {
std::vector<std::uint8_t> drain(HostTransport& transport) {
    StreamDecoder decoder;
    while (!transport.output().empty()) {
        CHECK(decoder.receive(transport.output().first(1)) == 1);
        transport.sent(1);
    }
    decoder.finish(); return decoder.take();
}
}
void transport_session() {
    SessionScenario f;
    HostTransport transport(f.host, f.remote, f.host.info());
    auto old = transport.connection();
    auto epoch = f.host.info().epoch;
    ClientState client(decode_resume(drain(transport), epoch), catalog());
    f.remoteLease = f.host.grant_lease(old, f.access());
    auto packet = f.packet(); auto wire = encode_stream(packet);
    auto request = decode_packet(packet, epoch).request; client.track(request);
    for (auto byte : wire) CHECK(transport.receive(std::span(&byte, 1), f.access()) == 1);
    CHECK(transport.receive(wire, f.access()) == 0);
    CHECK(!client.receive_receipt(drain(transport)));
    CHECK(client.status(request.id).status == TransactionStatus::Pending);
    f.written();
    // Durable result exists, but its receipt is lost after a partial socket write.
    auto joined = wire; joined.insert(joined.end(), wire.begin(), wire.end());
    CHECK(transport.receive(joined, f.access()) == wire.size());
    auto before = transport.output().size(); transport.sent(3);
    CHECK(transport.output().size() == before - 3);
    transport.disconnect(); client.disconnect();
    CHECK(f.host.players() == 1 && transport.output().empty());
    CHECK(client.status(request.id).status == TransactionStatus::Resolving);
    HostTransport resumed(f.host, f.remote, f.host.info());
    CHECK(resumed.connection() != old);
    client.reconnect(decode_resume(drain(resumed), epoch));
    rejects([&] { transport.receive(wire, f.access()); }, Error::InvalidState);
    transport.disconnect(); CHECK(f.host.players() == 2);
    CHECK(resumed.receive(wire, {}) == wire.size());
    CHECK(client.receive_receipt(drain(resumed)));
    CHECK(client.status(request.id).status == TransactionStatus::Committed);
    CHECK(f.s.probe->saves == 1);
    resumed.finish(); CHECK(f.host.players() == 1);
}
