#pragma once
#include "async_fixture.hpp"
#include "session.hpp"

inline SessionInfo session_info() {
    SessionInfo info;
    info.session = {12,1}; info.world = {13,1}; info.host = {77,1};
    info.catalogHash.fill(42);
    return info;
}
inline TransactionBudget::Clock::time_point fixed_time() { return {}; }
inline InteractionState observation(Id pawn) {
    return {pawn, true, true, {{id(10), 2.5, true, true},
                              {id(20), 0, true, true}, {id(30), 1, true, true}}};
}
struct SessionScenario {
    AsyncScenario s;
    HostSession host;
    AuthenticatedPeer remote{{77,2}, {14,2}};
    std::uint64_t localLease{}, remoteLease{};
    explicit SessionScenario(HostSession::Now now = fixed_time)
        : host(*s.inventory, session_info(), {14,1}, now) {
        localLease = host.grant_lease(HostSession::host_connection, local_access());
    }
    std::uint64_t join() {
        auto c = host.admit_authenticated(remote, host.info());
        remoteLease = host.grant_lease(c, access()); return c;
    }
    InteractionState access() { return observation(remote.pawn); }
    InteractionState local_access() { return observation({14,1}); }
    Request local_request() { auto r = s.request(); r.interactionLease = localLease; return r; }
    std::vector<std::uint8_t> packet() {
        PacketHeader h; h.worldEpoch = s.inventory->epoch();
        auto r = s.request(); r.interactionLease = remoteLease;
        return encode_packet(h, r);
    }
    void written() { eventually([&] { s.store->ready(); return !s.store->status().busy; }); }
};
