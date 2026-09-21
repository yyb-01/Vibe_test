#include "snapshot_transport_fixture.hpp"

namespace {
TransactionBudget::Clock::time_point page_now;
TransactionBudget::Clock::time_point page_clock() { return page_now; }
}
void transport_snapshot_pages() {
    page_now = {};
    World world;
    for (std::uint64_t n = 10; n < 13; ++n) {
        auto c = container(n); c.state.width = c.state.height = 32;
        world.containers.emplace(id(n), c);
        for (unsigned item = 0; item < 250; ++item)
            add_item(world, n * 1000 + item, 1, 1, n, item % 32, item / 32);
    }
    AsyncScenario storage(Inventory(catalog(), std::move(world), 1, 2).checkpoint());
    HostSession session(*storage.inventory, session_info(), {14,1}, page_clock);
    HostTransport host(session, {{77,2}, {14,2}}, session.info());
    auto info = session.info();
    ClientTransport client({{info.world, {77,2}, info.catalogHash}, info.epoch, 0, 1}, catalog());
    auto token = client.open_authenticated(info.epoch); host_to_client(host, client, token);
    InteractionState state{{14,2}, true, true,
        {{id(10),0,true,true}, {id(11),0,true,true}, {id(12),0,true,true}}};
    client.request_snapshot(token); client_to_host(client, token, host, state);
    snapshot_frame(host, client, token, state);
    CHECK(host.snapshot_output(state).size() == snapshot_page_limit + 4);
    snapshot_frame(host, client, token, state, 1000); CHECK(!client.state().view());
    // Exhaust command budget between pages. Busy retains the transfer for retry.
    bool busy = false;
    for (int n = 0; n < 25; ++n) {
        try { session.resume_state(host.connection()); }
        catch (const Violation& e) { CHECK(e.code == Error::Busy); busy = true; break; }
    }
    CHECK(busy);
    rejects([&] { host.snapshot_output(state); }, Error::Busy);
    CHECK(host.connection() && client.state().connected() && !client.state().view());
    page_now += std::chrono::milliseconds(100);
    snapshot_frame(host, client, token, state, 1000);
    CHECK(client.state().view()->items.size() == 750);
    CHECK(host.snapshot_output(state).empty() && !client.state().needs_refresh());
}
