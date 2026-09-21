#include "snapshot_transport_fixture.hpp"

void transport_snapshots() {
    SessionScenario f; auto baseline = transport_baseline(f);
    HostTransport host(f.host, f.remote, f.host.info()); ClientTransport client(baseline, catalog());
    auto token = client.open_authenticated(baseline.epoch);
    rejects([&] { client.request_snapshot(token); }, Error::NotAccessible);
    host_to_client(host, client, token); auto state = f.access();
    client.request_snapshot(token);
    rejects([&] { client.request_snapshot(token); }, Error::Busy);
    client_to_host(client, token, host, state);
    rejects([&] { host.shutdown(); }, Error::Busy);
    for (int n = 0; n < 30; ++n) CHECK(!host.snapshot_output(state).empty());
    snapshot_frame(host, client, token, state, 1);
    auto lease = client.snapshot_lease(token); CHECK(lease && !client.state().view());
    snapshot_frame(host, client, token, state, 1);
    CHECK(host.snapshot_output(state).empty());
    CHECK(client.state().view()->items.at(id(100)).quantity == 20);
    auto request = f.s.request(); request.interactionLease = lease;
    client.submit(token, request); client_to_host(client, token, host, state);
    host_to_client(host, client, token); f.written();
    client.retry(token, request.id); client_to_host(client, token, host, state);
    host_to_client(host, client, token); CHECK(client.state().needs_refresh());
    client.request_snapshot(token); CHECK(!client.state().view() && !client.snapshot_lease(token));
    client_to_host(client, token, host, state);
    snapshot_frame(host, client, token, state); snapshot_frame(host, client, token, state);
    CHECK(client.snapshot_lease(token) != lease && !client.state().needs_refresh());
    CHECK(client.state().view()->items.at(id(100)).quantity == 13 && client.state().sequence() == 1);
    state.roots.resize(1); client.request_snapshot(token); client_to_host(client, token, host, state);
    snapshot_frame(host, client, token, state); snapshot_frame(host, client, token, state);
    CHECK(!client.state().view()->items.contains(id(104)));
    CHECK(!client.state().view()->containers.contains(id(20)));
    CHECK(host.shutdown().applied()); host_to_client(host, client, token);
    CHECK(!client.state().connected() && !client.state().view());
}
