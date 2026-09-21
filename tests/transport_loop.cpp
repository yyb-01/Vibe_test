#include "client_transport_fixture.hpp"
#include "../demo/transport_loop.hpp"

void transport_loop() {
    SessionScenario f; auto baseline = transport_baseline(f);
    HostTransport host(f.host, f.remote, f.host.info());
    ClientTransport client(baseline, catalog());
    auto token = client.open_authenticated(baseline.epoch);
    auto tick = [&] {
        auto n = transport_tick(host, client, token, f.access(), 7);
        CHECK(n <= 21); return n;
    };
    CHECK(tick() == 7 && !client.state().connected());
    eventually([&] { tick(); return client.state().connected(); });
    client.request_snapshot(token);
    eventually([&] { tick(); return bool(client.state().view()); });
    f.remoteLease = client.snapshot_lease(token);
    auto request = decode_packet(f.packet(), baseline.epoch).request;
    client.submit(token, request);
    eventually([&] { tick(); return client.output(token).empty() && host.output().empty(); });
    CHECK(client.state().status(request.id).status == TransactionStatus::Pending);
    f.written(); client.retry(token, request.id);
    eventually([&] { tick(); return client.state().status(request.id).status == TransactionStatus::Committed; });
    CHECK(f.s.probe->saves == 1);
    client.request_snapshot(token);
    eventually([&] { tick(); return bool(client.state().view()); });
    CHECK(client.state().view()->items.at(id(100)).quantity == 13);
    CHECK(host.shutdown().applied());
    eventually([&] { tick(); return !host.connection(); });
    CHECK(!client.state().connected() && f.host.players() == 1);
    CHECK(client.state().status(request.id).status == TransactionStatus::Committed);
}

void transport_loop_failures() {
    using namespace std::chrono_literals;
    static TransportDeadlines::Clock::time_point time;
    auto now = +[] { return time; }; time = {};
    SessionScenario f(now); auto baseline = transport_baseline(f);
    HostTransport host(f.host, f.remote, f.host.info(), 1s, now);
    ClientTransport client(baseline, catalog(), 1s, now);
    auto token = client.open_authenticated(baseline.epoch);
    CHECK(transport_tick(host, client, token, f.access(), 0) == 0);
    time += 1s;
    CHECK(transport_tick(host, client, token, f.access()) == 0);
    CHECK(!host.connection() && !client.poll(token));
    HostTransport next(f.host, f.remote, f.host.info(), 1s, now);
    auto fresh = client.open_authenticated(baseline.epoch);
    CHECK(transport_tick(host, client, token, f.access()) == 0 && client.poll(fresh));
    host_to_client(next, client, fresh); client.request_snapshot(fresh);
    transport_tick(next, client, fresh, f.access()); // Request and offer only.
    while (f.host.receive(next.connection(), {}, f.access()).code != Error::Busy) {}
    CHECK(transport_tick(next, client, fresh, f.access()) == 0 && client.poll(fresh));
    time += 100ms;
    eventually([&] { transport_tick(next, client, fresh, f.access()); return bool(client.state().view()); });
    auto blocked = f.access(); blocked.roots[0].lineOfSight = false;
    rejects([&] { transport_tick(next, client, fresh, blocked); }, Error::NotAccessible);
    CHECK(!next.connection() && !client.state().connected() && !client.state().view());
}
