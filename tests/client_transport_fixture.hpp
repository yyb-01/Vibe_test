#pragma once
#include "session_fixture.hpp"
#include "transport.hpp"
#include "client_transport.hpp"

inline ResumeState transport_baseline(SessionScenario& f) {
    auto info = f.host.info();
    return {{info.world, f.remote.account, info.catalogHash}, info.epoch, 0, 1};
}
inline void host_to_client(HostTransport& host, ClientTransport& client, std::uint64_t token) {
    while (!host.output().empty()) {
        CHECK(client.receive(token, host.output().first(1)) == 1); host.sent(1);
    }
}
inline void client_to_host(ClientTransport& client, std::uint64_t token, HostTransport& host,
                            const InteractionState& observation) {
    while (!client.output(token).empty()) {
        CHECK(host.receive(client.output(token).first(1), observation) == 1); client.sent(token, 1);
    }
}
