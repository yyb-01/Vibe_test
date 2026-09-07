#pragma once
#include "write_set.hpp"
#include "checkpoint.hpp"
#include <map>
#include <memory>
#include <mutex>

namespace astra {
void validate(const Catalog&, World&);
std::vector<Id> ancestry(const World&, Id container);
void check_request(const World&, const Request&, const Access&);
void mutate(const Catalog&, World&, const Request&, Id created, std::uint64_t event);
World copy_roots(const World&, const std::set<Id>& roots);
World copy_roots(const RootViews&, const std::set<Id>& roots);
RootViews partition_roots(const World&);

// Process-local atomic state. No durable Committed acknowledgement is exposed.
class Inventory {
public:
    Inventory(Catalog catalog, World initial, std::uint64_t epoch, std::uint64_t idOrigin);
    explicit Inventory(Checkpoint);
    Checkpoint checkpoint() const;
    // Host-only durable staging; requires exactly one owned pending transaction.
    Checkpoint checkpoint_after(const std::shared_ptr<const WriteSet>&) const;
    Result apply(const Request&, const Access&);
    // Host-only lifecycle. One transaction per account; disjoint roots can wait together.
    Preparation prepare(const Request&, const Access&);
    Result commit(const std::shared_ptr<const WriteSet>&);
    // Call only after a definite abort; keep pending on unknown storage outcome.
    bool abort(const std::shared_ptr<const WriteSet>&);
    std::shared_ptr<const World> snapshot() const;
    RootSnapshot snapshot_roots(const std::set<Id>& roots) const;
private:
    struct Record {
        std::vector<std::uint8_t> payload;
        Result result;
        std::weak_ptr<const WriteSet> handle;
    };
    using RecordMap = std::map<std::pair<Id, Id>, Record>;
    using AccountMap = std::map<Id, std::uint64_t>;
    struct Pending {
        std::shared_ptr<const WriteSet> changes;
        World rows; // Preallocated replacement/insertion nodes; no allocation at commit.
        RootViews roots; // Immutable post-transaction versions of affected roots.
        RecordMap::node_type record;
        AccountMap::node_type account;
    };
    Preparation prepare_locked(const Request&, const Access&);
    Result commit_locked(const std::shared_ptr<const WriteSet>&);
    Checkpoint checkpoint_locked() const;
    const Catalog catalog_;
    const std::uint64_t epoch_, origin_;
    std::uint64_t sequence_{}, nextId_{1}, nextEvent_{1};
    World world_; // Private mutable index, protected by mutex_; never returned to readers.
    RootViews roots_;
    mutable std::weak_ptr<const World> flatSnapshot_;
    RecordMap records_;
    AccountMap accountSeq_;
    std::map<Id, Pending> pending_; // Account -> reservation and sparse changes.
    mutable std::mutex mutex_;
};
}
