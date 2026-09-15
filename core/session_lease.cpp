#include "session.hpp"

namespace astra {
std::uint64_t HostSession::grant_lease(std::uint64_t connection, const InteractionState& state) {
    owner(); require(!closing_, Error::Busy);
    auto& p = peer(connection);
    auto roots = interaction_roots(state, p.pawn);
    try { (void)inventory_.snapshot_roots(roots); }
    catch (const Violation&) { throw Violation{Error::NotAccessible}; }
    require(nextLease_ < revision_limit, Error::LimitExceeded);
    auto now = now_();
    require(now <= TransactionBudget::Clock::time_point::max() - interaction_lease_lifetime, Error::InvalidState);
    p.lease = {nextLease_++, now, now + interaction_lease_lifetime, std::move(roots)};
    p.snapshot.reset();
    return p.lease.token;
}
void HostSession::revoke_lease(std::uint64_t connection) {
    owner(); auto& p = peer(connection); p.lease = {}; p.snapshot.reset();
}
Access HostSession::authorize(Peer& p, std::uint64_t token, const InteractionState& state) const {
    auto now = now_();
    require(token && token == p.lease.token && now >= p.lease.issued && now < p.lease.expires,
            Error::NotAccessible);
    auto roots = interaction_roots(state, p.pawn);
    require(roots == p.lease.roots, Error::NotAccessible);
    return {p.account, info_.epoch, token, std::move(roots)};
}
RootSnapshot HostSession::view(std::uint64_t connection, std::uint64_t token, const InteractionState& state) {
    owner();
    auto& p = admit_command(connection);
    auto access = authorize(p, token, state);
    try { return inventory_.snapshot_roots(access.roots); }
    catch (const Violation&) { throw Violation{Error::NotAccessible}; }
}
}
