#pragma once
#include "durable.hpp"
#include "packet.hpp"
#include "transaction_budget.hpp"
#include "interaction.hpp"
#include "snapshot.hpp"
#include "reconnect.hpp"
#include <array>
#include <thread>

namespace astra {
enum class IdentityKind { Platform, LocalLan };
struct SessionInfo {
    Id session, world, host;
    std::array<std::uint8_t, 32> catalogHash{};
    std::uint64_t epoch{};
    std::uint16_t protocol{protocol_version};
    IdentityKind identity{IdentityKind::Platform};
    bool operator==(const SessionInfo&) const = default;
};
// Produced by the trusted platform/LAN adapter, never by decoding client claims.
// pawn is allocated by the authoritative host after authentication.
struct AuthenticatedPeer { Id account, pawn; IdentityKind identity{IdentityKind::Platform}; };
class HostSession {
public:
    static constexpr std::size_t max_players = 20;
    static constexpr std::uint64_t host_connection = 1;
    using Now = TransactionBudget::Clock::time_point(*)();
    HostSession(DurableInventory&, SessionInfo, Id hostPawn, Now = TransactionBudget::Clock::now);
    HostSession(const HostSession&) = delete;
    HostSession& operator=(const HostSession&) = delete;
    const SessionInfo& info() const { owner(); return info_; }
    std::size_t players() const;
    std::uint64_t admit_authenticated(const AuthenticatedPeer&, const SessionInfo& handshake);
    void disconnect(std::uint64_t connection);
    ResumeState resume_state(std::uint64_t connection);
    std::uint64_t grant_lease(std::uint64_t connection, const InteractionState&);
    void revoke_lease(std::uint64_t connection);
    RootSnapshot view(std::uint64_t connection, std::uint64_t lease, const InteractionState&);
    SnapshotDescriptor start_snapshot(std::uint64_t, std::uint64_t lease, const InteractionState&);
    std::vector<std::uint8_t> snapshot_page(std::uint64_t, Id snapshot, std::size_t page, const InteractionState&);
    void validate_snapshot(std::uint64_t, Id snapshot, const InteractionState&); // No rate budget; before each write.
    Result receive(std::uint64_t connection, const std::vector<std::uint8_t>&,
                   const InteractionState&, std::size_t pathBudget = datagram_limit);
    Result apply_local(const Request&, const InteractionState&);
    Result close();
    Result prepare_close(); // On Ok, notify participants before calling close().
private:
    struct Peer {
        std::uint64_t connection{}; Id account, pawn; InteractionLease lease;
        std::unique_ptr<SnapshotData> snapshot;
    };
    void owner() const;
    Peer& peer(std::uint64_t);
    Peer& admit_command(std::uint64_t);
    Access authorize(Peer&, std::uint64_t, const InteractionState&) const;
    Result dispatch(Peer&, const Request&, const InteractionState&);
    Result failure(Error) const;
    DurableInventory& inventory_;
    Now now_;
    SessionInfo info_;
    std::array<Peer, max_players> peers_{};
    std::map<Id, TransactionBudget> budgets_;
    std::uint64_t nextConnection_{2};
    std::uint64_t nextLease_{1};
    std::uint64_t nextSnapshot_{1};
    bool closing_{};
    const std::thread::id owner_{std::this_thread::get_id()};
};
}
