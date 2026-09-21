#include "snapshot_transport_fixture.hpp"

namespace {
TransactionBudget::Clock::time_point snapshot_now;
TransactionBudget::Clock::time_point snapshot_clock() { return snapshot_now; }
}
void transport_snapshot_failures() {
    for (int failure = 0; failure < 6; ++failure) {
        snapshot_now = {}; SessionScenario f(snapshot_clock); auto baseline = transport_baseline(f);
        HostTransport host(f.host, f.remote, f.host.info()); ClientTransport client(baseline, catalog());
        auto token = client.open_authenticated(baseline.epoch); host_to_client(host, client, token);
        auto state = f.access(); client.request_snapshot(token); client_to_host(client, token, host, state);
        snapshot_frame(host, client, token, state);
        auto span = host.snapshot_output(state); std::vector<std::uint8_t> page(span.begin(), span.end());
        if (failure < 3) {
            CHECK(client.receive_snapshot(token, std::span(page).first(1)) == 1); host.snapshot_sent(1);
            if (failure == 0) state.roots[0].lineOfSight = false;
            if (failure == 1) f.host.revoke_lease(host.connection());
            if (failure == 2) snapshot_now += interaction_lease_lifetime;
            rejects([&] { host.snapshot_output(state); }, Error::NotAccessible);
            CHECK(!host.connection() && f.host.players() == 1);
            rejects([&] { client.finish_snapshot(token); }, Error::InvalidRequest);
        } else if (failure == 3) {
            page.back() ^= 1;
            rejects([&] { client.receive_snapshot(token, page); }, Error::InvalidRequest);
        } else {
            if (failure == 5) CHECK(client.receive_snapshot(token, std::span(page).first(1)) == 1);
            rejects([&] { client.finish_snapshot(token); }, Error::InvalidRequest);
        }
        CHECK(!client.state().connected() && !client.state().view()); host.disconnect();
        auto fresh = client.open_authenticated(baseline.epoch); client.disconnect(token);
        rejects([&] { client.receive_snapshot(token, page); }, Error::InvalidState);
        HostTransport next(f.host, f.remote, f.host.info()); host_to_client(next, client, fresh);
        CHECK(client.state().connected());
        client.request_snapshot(fresh); client_to_host(client, fresh, next, f.access());
        snapshot_frame(next, client, fresh, f.access()); snapshot_frame(next, client, fresh, f.access());
        CHECK(client.state().view());
    }
}
