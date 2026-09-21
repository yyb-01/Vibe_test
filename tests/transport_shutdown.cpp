#include "client_transport_fixture.hpp"

void transport_shutdown() {
    SessionScenario f; auto baseline = transport_baseline(f);
    HostTransport host(f.host, f.remote, f.host.info());
    ClientTransport client(baseline, catalog());
    auto token = client.open_authenticated(baseline.epoch);
    rejects([&] { host.shutdown(); }, Error::Busy); // Resume cannot be overwritten.
    host_to_client(host, client, token);
    f.remoteLease = f.host.grant_lease(host.connection(), f.access());
    auto request = decode_packet(f.packet(), baseline.epoch).request;
    { std::lock_guard lock(f.s.probe->mutex); f.s.probe->hold = true; }
    client.submit(token, request); client_to_host(client, token, host, f.access());
    rejects([&] { host.shutdown(); }, Error::Busy); // Pending receipt is drained first.
    host_to_client(host, client, token);
    CHECK(host.shutdown().code == Error::Pending && host.output().empty());
    CHECK(client.state().connected() && host.connection());
    f.s.probe->release(); Result ready;
    eventually([&] { ready = host.shutdown(); return ready.code != Error::Pending; });
    CHECK(ready.applied() && f.s.probe->closes == 0);
    CHECK(host.receive(encode_stream(f.packet()), f.access()) == 0);
    CHECK(client.receive(token, host.output().first(1)) == 1); host.sent(1);
    CHECK(client.state().connected() && host.connection());
    host_to_client(host, client, token);
    CHECK(!client.state().connected() && !host.connection() && f.host.players() == 1);
    CHECK(client.state().status(request.id).status == TransactionStatus::Resolving);
    CHECK(client.state().retry_payload(request.id) == encode(request));
    CHECK(f.s.probe->closes == 0); // Notification does not close storage.
    Result closed;
    eventually([&] { closed = f.host.close(); return closed.code != Error::Pending; });
    CHECK(closed.applied() && f.s.probe->saves == 1);
}
