#include "session.hpp"

namespace astra {
Result HostSession::failure(Error error) const {
    return {error, inventory_.snapshot_roots({}).sequence, {}};
}
HostSession::Peer& HostSession::peer(std::uint64_t connection) {
    for (auto& p : peers_) if (connection && p.connection == connection) return p;
    throw Violation{Error::NotAccessible};
}
HostSession::Peer& HostSession::admit_command(std::uint64_t connection) {
    require(!closing_, Error::Busy);
    auto& p = peer(connection);
    require(budgets_.at(p.account).take(now_()), Error::Busy);
    return p;
}
Result HostSession::dispatch(Peer& p, const Request& request, const InteractionState& state) {
    // A revoked lease must not turn an already durable or unresolved request into a rejection.
    if (auto known = inventory_.result_for(request, p.account)) return *known;
    return inventory_.apply(request, authorize(p, request.interactionLease, state));
}
Result HostSession::receive(std::uint64_t connection, const std::vector<std::uint8_t>& bytes,
                            const InteractionState& state, std::size_t budget) {
    owner();
    try {
        auto& p = admit_command(connection); // Malformed packets also consume budget.
        auto packet = decode_packet(bytes, info_.epoch, budget);
        return dispatch(p, packet.request, state);
    } catch (const Violation& e) { return failure(e.code); }
}
Result HostSession::apply_local(const Request& request, const InteractionState& state) {
    owner();
    try { return dispatch(admit_command(host_connection), request, state); }
    catch (const Violation& e) { return failure(e.code); }
}
}
