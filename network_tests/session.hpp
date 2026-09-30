#pragma once
#include "loopback.hpp"
#include "../tests/client_transport_fixture.hpp"

struct TcpSession {
    SessionScenario f;
    ResumeState baseline{transport_baseline(f)};
    ClientTransport client;
    std::uint64_t token{};
    std::unique_ptr<HostTransport> host;
    std::unique_ptr<Loopback> command, snapshot;
    TransportDeadlines::Now now;
    explicit TcpSession(TransportDeadlines::Now clock = fixed_time) :
        client(baseline, catalog(), std::chrono::seconds(1), clock), now(clock) { connect(); }
    void connect();
    void drop();
    void tick(std::size_t chunk = 7, bool sendSnapshot = true);
    void host_tick(std::size_t chunk, bool sendSnapshot);
    void client_tick(std::size_t chunk);
    void ready() { eventually([&] { tick(); return client.state().connected(); }); }
    void drain() {
        eventually([&] { tick(); return client.output(token).empty() && host->output().empty() &&
            command->server->read().empty() && command->client.read().empty(); });
    }
};
