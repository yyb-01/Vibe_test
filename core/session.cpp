#include "session.hpp"
#include <algorithm>

namespace astra {
HostSession::HostSession(DurableInventory& inventory, SessionInfo info, Id pawn, Now now)
    : inventory_(inventory), now_(now), info_(info) {
    require(now_ != nullptr, Error::InvalidState);
    require(bool(info.session) && bool(info.world) && bool(info.host) && bool(pawn), Error::InvalidState);
    require(info.protocol == protocol_version, Error::Incompatible);
    require(info.identity == IdentityKind::Platform || info.identity == IdentityKind::LocalLan, Error::InvalidState);
    info_.epoch = inventory.epoch();
    budgets_.try_emplace(info.host, now_());
    peers_[0] = {host_connection, info.host, pawn, {}, {}};
}
void HostSession::owner() const {
    require(std::this_thread::get_id() == owner_, Error::InvalidState);
}
std::size_t HostSession::players() const {
    owner();
    return std::count_if(peers_.begin(), peers_.end(), [](const Peer& p) { return p.connection != 0; });
}
std::uint64_t HostSession::admit_authenticated(const AuthenticatedPeer& peer, const SessionInfo& handshake) {
    owner(); require(!closing_, Error::Busy);
    require(handshake.epoch == info_.epoch, Error::EpochMismatch);
    require(handshake == info_, Error::Incompatible);
    require(bool(peer.account) && bool(peer.pawn) && peer.identity == info_.identity, Error::NotAccessible);
    for (const auto& p : peers_)
        require(!p.connection || (p.account != peer.account && p.pawn != peer.pawn), Error::NotAccessible);
    auto slot = std::find_if(peers_.begin(), peers_.end(), [](const Peer& p) { return !p.connection; });
    require(slot != peers_.end() && nextConnection_ < UINT64_MAX, Error::LimitExceeded);
    require(budgets_.contains(peer.account) || budgets_.size() < 64, Error::LimitExceeded);
    budgets_.try_emplace(peer.account, now_());
    *slot = {nextConnection_++, peer.account, peer.pawn, {}, {}};
    return slot->connection;
}
void HostSession::disconnect(std::uint64_t connection) {
    owner(); require(connection != host_connection, Error::NotAccessible);
    for (auto& p : peers_) if (p.connection == connection) { p = {}; return; }
}
Result HostSession::close() {
    owner(); closing_ = true;
    auto result = inventory_.close();
    if (result.applied()) peers_ = {};
    return result;
}
}
