#include "client_transport_fixture.hpp"

namespace {
using Clock = TransportDeadlines::Clock;
using namespace std::chrono_literals;
}
void client_transport_deadlines() {
    static Clock::time_point time;
    auto now = +[] { return time; };
    time = {}; SessionScenario f; auto baseline = transport_baseline(f);
    ClientTransport client(baseline, catalog(), 1s, now);
    auto token = client.open_authenticated(baseline.epoch);
    time += 1s; CHECK(!client.poll(token)); // No initial resume.
    HostTransport host(f.host, f.remote, f.host.info());
    auto fresh = client.open_authenticated(baseline.epoch);
    CHECK(!client.poll(token) && client.poll(fresh)); token = fresh;
    host_to_client(host, client, token);
    time += 2s; CHECK(client.poll(token)); // Completed resume, idle connection.
    f.remoteLease = f.host.grant_lease(host.connection(), f.access());
    auto request = decode_packet(f.packet(), baseline.epoch).request;
    client.submit(token, request);
    auto original = client.state().retry_payload(request.id);
    time += 999ms; client.sent(token, 1); time += 1ms;
    CHECK(!client.poll(token));
    CHECK(client.state().status(request.id).status == TransactionStatus::Resolving);
    CHECK(client.state().retry_payload(request.id) == original);
    host.disconnect();
    HostTransport next(f.host, f.remote, f.host.info());
    fresh = client.open_authenticated(baseline.epoch);
    CHECK(!client.poll(token)); host_to_client(next, client, fresh);
    client.retry(fresh, request.id); client_to_host(client, fresh, next, f.access());
    CHECK(client.receive(fresh, next.output().first(1)) == 1); next.sent(1);
    time += 999ms;
    CHECK(client.receive(fresh, next.output().first(1)) == 1); next.sent(1);
    time += 1ms;
    rejects([&] { client.receive(fresh, next.output()); }, Error::InvalidState);
    CHECK(!client.state().connected());
    CHECK(client.state().retry_payload(request.id) == original);
    CHECK(client.state().status(request.id).status == TransactionStatus::Resolving);
    next.disconnect();
    fresh = client.open_authenticated(baseline.epoch);
    time -= 1ms; rejects([&] { client.poll(fresh); }, Error::InvalidState);
    CHECK(!client.poll(fresh));
}
