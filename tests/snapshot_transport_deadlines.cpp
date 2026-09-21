#include "snapshot_transport_fixture.hpp"

namespace {
using Clock = TransportDeadlines::Clock;
using namespace std::chrono_literals;
}
void snapshot_transport_deadlines() {
    static Clock::time_point time;
    auto now = +[] { return time; };
    for (int mode = 0; mode < 4; ++mode) {
        time = {}; SessionScenario f; auto baseline = transport_baseline(f);
        HostTransport host(f.host, f.remote, f.host.info(), 1s, now);
        ClientTransport client(baseline, catalog(), 1s, now);
        auto token = client.open_authenticated(baseline.epoch);
        host_to_client(host, client, token); client.request_snapshot(token);
        client_to_host(client, token, host, f.access());
        time += 600ms;
        if (mode > 0) snapshot_frame(host, client, token, f.access());
        time += 399ms;
        CHECK(host.poll() && client.poll(token));
        if (mode == 2) {
            CHECK(client.receive_snapshot(token, host.snapshot_output(f.access()).first(1)) == 1);
            host.snapshot_sent(1);
        }
        if (mode == 3) {
            snapshot_frame(host, client, token, f.access()); CHECK(client.state().view());
        }
        time += 1ms;
        if (mode == 3) {
            CHECK(host.poll() && client.poll(token)); // Both transfer deadlines cleared.
            time += 2s; CHECK(host.poll() && client.poll(token));
        } else {
            rejects([&] { host.snapshot_output(f.access()); }, Error::InvalidState);
            rejects([&] { client.receive_snapshot(token, {}); }, Error::InvalidState);
            CHECK(!host.connection() && f.host.players() == 1);
            CHECK(!client.state().connected() && !client.state().view());
        }
    }
    time = {}; SessionScenario f; auto baseline = transport_baseline(f);
    HostTransport host(f.host, f.remote, f.host.info());
    ClientTransport client(baseline, catalog(), 1s, now);
    auto token = client.open_authenticated(baseline.epoch); host_to_client(host, client, token);
    client.request_snapshot(token); client.sent(token, client.output(token).size());
    time += 1s; CHECK(!client.poll(token)); // Request sent but no offer ever arrives.
}
