#include "multiplayer_fixture.hpp"

void multiplayer_lifecycle() {
    MultiplayerScenario m; m.ready();
    CHECK(m.f.host.players() == 20);
    rejects([&] { HostTransport extra(m.f.host, {{77,21},{14,21}}, m.f.host.info()); }, Error::LimitExceeded);
    for (auto& p : m.peers) p.client->request_snapshot(p.token);
    eventually([&] {
        m.tick(0);
        return std::all_of(m.peers.begin() + 1, m.peers.end(), [](auto& p) { return bool(p.client->state().view()); });
    });
    auto& first = m.peers[0];
    CHECK(!first.client->state().view() && first.client->state().connected());
    eventually([&] { m.tick(); return bool(first.client->state().view()); });
    auto token = first.token; auto connection = first.host->connection();
    first.host->disconnect(); first.client->disconnect(token);
    CHECK(m.f.host.players() == 19);
    m.connect(0); m.ready();
    CHECK(first.token != token && first.host->connection() != connection && m.f.host.players() == 20);
    first.client->disconnect(token);
    rejects([&] { first.client->receive(token, {}); }, Error::InvalidState);
    for (auto& p : m.peers) CHECK(p.client->state().connected());
    for (auto& p : m.peers) CHECK(p.host->shutdown().applied());
    rejects([&] { HostTransport extra(m.f.host, {{77,21},{14,21}}, m.f.host.info()); }, Error::Busy);
    eventually([&] { m.tick(); return m.f.host.players() == 1; });
    for (auto& p : m.peers) CHECK(!p.client->state().connected() && !p.client->state().view());
    CHECK(m.f.s.probe->closes == 0);
    eventually([&] { return m.f.host.close().applied(); });
    CHECK(m.f.host.players() == 0 && m.f.s.probe->closes == 1);
}
