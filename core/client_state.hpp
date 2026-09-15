#pragma once
#include "receipt.hpp"
#include "snapshot.hpp"
#include "reconnect.hpp"
#include <optional>
#include <set>

namespace astra {
// Owner-thread UI model. Inputs must arrive from the authenticated server/session.
class ClientState {
public:
    ClientState(std::uint64_t epoch, Catalog);
    ClientState(const ResumeState&, Catalog);
    void disconnect();
    void reconnect(const ResumeState& authenticated);
    bool connected() const { return connected_; }
    std::uint64_t resume_action_sequence() const { return resumeSequence_; }
    void track(const Request&);
    void forget(Id request); // Only final requests can leave the bounded tracking table.
    const TransactionReceipt& status(Id request) const;
    const std::vector<std::uint8_t>& retry_payload(Id request) const;
    bool receive_receipt(const std::vector<std::uint8_t>&);
    void timeout(Id request);
    // Call on lease replacement/revocation, even if the root set is unchanged.
    void set_roots(std::set<Id> approvedRoots);
    void begin_snapshot(const SnapshotDescriptor&);
    bool receive_page(const std::vector<std::uint8_t>&);
    std::shared_ptr<const World> view() const { return view_; }
    bool needs_refresh() const { return !roots_.empty() && (!view_ || published_ < confirmed_); }
    std::uint64_t sequence() const { return published_; }
private:
    struct Tracked { std::vector<std::uint8_t> payload; TransactionReceipt receipt; };
    Tracked& tracked(Id);
    const Tracked& tracked(Id) const;
    std::uint64_t epoch_;
    const Catalog catalog_;
    std::map<Id, Tracked> requests_;
    std::set<Id> roots_;
    std::optional<SnapshotDescriptor> latest_;
    std::unique_ptr<SnapshotAssembly> assembly_;
    std::shared_ptr<const World> view_;
    std::uint64_t published_{}, confirmed_{};
    std::optional<ClientIdentity> identity_;
    std::uint64_t resumeSequence_{};
    bool connected_{true};
};
}
