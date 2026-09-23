#pragma once
#include "client_transport_fixture.hpp"
#include "../demo/transport_loop.hpp"

struct MultiplayerScenario {
    SessionScenario f;
    struct Peer {
        AuthenticatedPeer identity;
        std::unique_ptr<HostTransport> host;
        std::unique_ptr<ClientTransport> client;
        std::uint64_t token{};
    };
    std::array<Peer, HostSession::max_players - 1> peers;
    MultiplayerScenario() {
        for (std::size_t i = 0; i < peers.size(); ++i) {
            auto& p = peers[i]; p.identity = {{77, i + 2}, {14, i + 2}};
            auto baseline = transport_baseline(f); baseline.identity.account = p.identity.account;
            p.client = std::make_unique<ClientTransport>(baseline, catalog());
            connect(i);
        }
    }
    void connect(std::size_t i) {
        auto& p = peers[i];
        p.host = std::make_unique<HostTransport>(f.host, p.identity, f.host.info());
        p.token = p.client->open_authenticated(f.host.info().epoch);
    }
    void tick(std::size_t blocked = HostSession::max_players) {
        for (std::size_t i = 0; i < peers.size(); ++i) {
            auto& p = peers[i]; auto chunk = i == blocked ? 0u : 7u;
            CHECK(transport_tick(*p.host, *p.client, p.token, observation(p.identity.pawn), chunk) <= chunk * 3);
        }
    }
    void ready() {
        eventually([&] {
            tick();
            return std::all_of(peers.begin(), peers.end(), [](auto& p) { return p.client->state().connected(); });
        });
    }
    void drain() {
        eventually([&] {
            tick();
            return std::all_of(peers.begin(), peers.end(), [](auto& p) {
                return p.client->output(p.token).empty() && p.host->output().empty();
            });
        });
    }
};
