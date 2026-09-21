#include "client_transport_fixture.hpp"

void client_transport_session() {
    SessionScenario f; auto baseline = transport_baseline(f);
    HostTransport host(f.host, f.remote, f.host.info());
    ClientTransport client(baseline, catalog());
    auto token = client.open_authenticated(baseline.epoch);
    rejects([&] { client.submit(token, f.s.request()); }, Error::NotAccessible);
    host_to_client(host, client, token); CHECK(client.state().connected());
    f.remoteLease = f.host.grant_lease(host.connection(), f.access());
    auto request = decode_packet(f.packet(), baseline.epoch).request;
    client.submit(token, request); auto original = client.state().retry_payload(request.id);
    rejects([&] { client.submit(token, request); }, Error::Busy);
    rejects([&] { client.sent(token, client.output(token).size() + 1); }, Error::InvalidRequest);
    client_to_host(client, token, host, f.access()); host_to_client(host, client, token);
    CHECK(client.state().status(request.id).status == TransactionStatus::Pending);
    client.timeout(token, request.id);
    CHECK(client.state().status(request.id).status == TransactionStatus::Resolving);
    f.written(); client.retry(token, request.id); client_to_host(client, token, host, {});
    // Lose the final receipt after one byte; the next connection must reset its decoder.
    CHECK(client.receive(token, host.output().first(1)) == 1); host.sent(1);
    client.disconnect(token); host.disconnect();
    HostTransport next(f.host, f.remote, f.host.info());
    auto fresh = client.open_authenticated(baseline.epoch); CHECK(fresh != token);
    client.disconnect(token);
    rejects([&] { client.receive(token, next.output()); }, Error::InvalidState);
    rejects([&] { client.sent(token, 1); }, Error::InvalidState);
    rejects([&] { client.finish(token); }, Error::InvalidState);
    host_to_client(next, client, fresh); CHECK(client.state().connected());
    client.retry(fresh, request.id); client_to_host(client, fresh, next, {});
    host_to_client(next, client, fresh);
    CHECK(client.state().status(request.id).status == TransactionStatus::Committed);
    CHECK(client.state().retry_payload(request.id) == original && f.s.probe->saves == 1);
    client.forget(request.id);
    rejects([&] { client.state().status(request.id); }, Error::InvalidRequest);
    client.finish(fresh); CHECK(!client.state().connected());
}
