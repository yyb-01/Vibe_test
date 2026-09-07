#pragma once
#include "inventory.hpp"

namespace astra {
struct StoredWorld { Checkpoint checkpoint; std::uint64_t version{}; };
enum class SaveOutcome { Committed, Aborted, Unknown, Fenced };
class DurableStore {
public:
    virtual ~DurableStore() = default;
    // Atomically acquire a new epoch/origin and recover, or initialize from seed.
    virtual StoredWorld acquire(const Checkpoint& seed) = 0;
    virtual SaveOutcome save(std::uint64_t version, const Checkpoint&, const SavedRequest&) = 0;
    // Must wait for any previous save to finish (e.g. lock the same DB world row).
    virtual StoredWorld inspect() = 0;
};
// Synchronous persistence coordinator: call from a DB worker, not the game tick.
// This initial adapter serializes durable writes per world; memory-only Inventory
// retains its independent-root workflow. No mutable Inventory escapes this owner.
class DurableInventory {
public:
    DurableInventory(std::unique_ptr<DurableStore>, const Checkpoint& seed);
    Result apply(const Request&, const Access&);
    Result resolve();
    std::uint64_t epoch() const { return epoch_; }
    std::shared_ptr<const World> snapshot() const { return inventory_->snapshot(); }
    RootSnapshot snapshot_roots(const std::set<Id>& roots) const { return inventory_->snapshot_roots(roots); }
private:
    struct Waiting { std::shared_ptr<const WriteSet> changes; Checkpoint target; };
    Result finish(SaveOutcome);
    Result resolve_locked();
    std::unique_ptr<DurableStore> store_;
    std::unique_ptr<Inventory> inventory_;
    std::unique_ptr<Waiting> waiting_;
    std::uint64_t epoch_{}, version_{};
    bool fenced_{};
    std::mutex mutex_;
};
}
