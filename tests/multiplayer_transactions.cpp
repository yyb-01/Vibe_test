#include "multiplayer_fixture.hpp"

void multiplayer_transactions() {
    MultiplayerScenario m; m.ready();
    auto& a = m.peers[0]; auto& b = m.peers[1];
    auto first = m.f.s.request(), second = first; second.id = {88,2};
    first.interactionLease = m.f.host.grant_lease(a.host->connection(), observation(a.identity.pawn));
    second.interactionLease = m.f.host.grant_lease(b.host->connection(), observation(b.identity.pawn));
    a.client->submit(a.token, first); b.client->submit(b.token, second);
    m.drain();
    CHECK(a.client->state().status(first.id).status == TransactionStatus::Pending);
    CHECK(b.client->state().status(second.id).reason == ClientReason::Busy);
    CHECK(m.f.s.inventory->snapshot()->items.at(id(100)).quantity == 20);
    m.f.written(); a.client->retry(a.token, first.id);
    client_to_host(*a.client, a.token, *a.host, observation(a.identity.pawn));
    CHECK(a.client->receive(a.token, a.host->output().first(1)) == 1); a.host->sent(1);
    // Lose the final receipt while the other 18 connections remain alive.
    auto old = a.token; a.host->disconnect(); a.client->disconnect(old);
    m.connect(0); m.ready(); a.client->retry(a.token, first.id); m.drain();
    CHECK(a.client->state().status(first.id).status == TransactionStatus::Committed);
    CHECK(m.f.s.probe->saves == 1);
    b.client->retry(b.token, second.id); m.drain(); m.f.written();
    b.client->retry(b.token, second.id); m.drain();
    CHECK(b.client->state().status(second.id).status == TransactionStatus::Rejected);
    CHECK(b.client->state().status(second.id).reason == ClientReason::RevisionConflict);
    CHECK(m.f.s.inventory->snapshot()->items.at(id(100)).quantity == 13);
    auto saves = m.f.s.probe->saves.load();
    a.client->retry(a.token, first.id); b.client->retry(b.token, second.id); m.drain();
    CHECK(m.f.s.probe->saves == saves && m.f.host.players() == 20);
    for (auto& p : m.peers) p.client->request_snapshot(p.token);
    eventually([&] {
        m.tick();
        return std::all_of(m.peers.begin(), m.peers.end(), [](auto& p) { return bool(p.client->state().view()); });
    });
    for (auto& p : m.peers) CHECK(p.client->state().view()->items.at(id(100)).quantity == 13);
}
