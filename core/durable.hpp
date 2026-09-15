#pragma once
#include "inventory.hpp"

namespace astra {
struct StoredWorld { Checkpoint checkpoint; std::uint64_t version{}; };
enum class SaveOutcome { Committed, Aborted, Unknown, Fenced, Limited };
class DurableStore {
public:
    virtual ~DurableStore() = default;
    // Atomically acquire a new epoch/origin and recover, or initialize from seed.
    virtual StoredWorld acquire(const Checkpoint& seed) = 0;
    virtual SaveOutcome save(std::uint64_t version, const Checkpoint&, const SavedRequest&) = 0;
    // Optional sparse owner-to-worker path; legacy synchronous stores keep save().
    virtual bool delta_writes() const { return false; }
    virtual SaveOutcome save_delta(std::uint64_t, const CheckpointDelta&) { throw Violation{Error::InvalidState}; }
    virtual SaveOutcome resolve_delta() { throw Violation{Error::InvalidState}; }
    // Must wait for any previous save to finish (e.g. lock the same DB world row).
    virtual StoredWorld inspect() = 0;
    // Explicit normal shutdown. Throw on failure; callers can retry.
    virtual void close() {}
};
// Direct stores block. AsyncStore moves DB calls to a worker while this owner publishes.
// This initial adapter serializes durable writes per world; memory-only Inventory
// retains its independent-root workflow. No mutable Inventory escapes this owner.
class DurableInventory {
public:
    DurableInventory(std::unique_ptr<DurableStore>, const Checkpoint& seed);
    Result apply(const Request&, const Access&);
    std::optional<Result> result_for(const Request&, Id account);
    Result resolve();
    // Stop admission, settle pending work, then close storage. Retry Pending/errors.
    // Ok describes shutdown, not the outcome of a previously pending request.
    Result close();
    std::uint64_t epoch() const { return epoch_; }
    std::uint64_t next_action_sequence(Id account) const { return inventory_->next_action_sequence(account); }
    std::shared_ptr<const World> snapshot() const { return inventory_->snapshot(); }
    RootSnapshot snapshot_roots(const std::set<Id>& roots) const { return inventory_->snapshot_roots(roots); }
private:
    struct Waiting {
        std::shared_ptr<const WriteSet> changes;
        Checkpoint target;
        std::optional<CheckpointDelta> delta;
    };
    Result finish(SaveOutcome);
    Result resolve_locked();
    std::unique_ptr<DurableStore> store_;
    std::unique_ptr<Inventory> inventory_;
    std::unique_ptr<Waiting> waiting_;
    std::uint64_t epoch_{}, version_{};
    bool fenced_{}, closing_{}, closed_{};
    std::mutex mutex_;
};
}
