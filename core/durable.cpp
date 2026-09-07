#include "durable.hpp"

namespace astra {
DurableInventory::DurableInventory(std::unique_ptr<DurableStore> store, const Checkpoint& seed)
    : store_(std::move(store)) {
    require(bool(store_), Error::InvalidState);
    auto loaded = store_->acquire(seed);
    require(loaded.checkpoint.catalog == seed.catalog, Error::Incompatible);
    epoch_ = loaded.checkpoint.epoch; version_ = loaded.version;
    inventory_ = std::make_unique<Inventory>(std::move(loaded.checkpoint));
}
Result DurableInventory::apply(const Request& request, const Access& access) {
    std::lock_guard lock(mutex_);
    auto sequence = inventory_->snapshot_roots({}).sequence;
    if (fenced_ || access.epoch != epoch_) return {Error::EpochMismatch, sequence, {}};
    if (!access.account) return {Error::NotAccessible, sequence, {}};
    if (waiting_) {
        if (waiting_->changes->account != access.account || waiting_->changes->requestId != request.id)
            return {Error::Busy, sequence, {}};
        try {
            if (waiting_->changes->payload != encode(request)) return {Error::IdempotencyMismatch, sequence, {}};
        } catch (const Violation& error) { return {error.code, sequence, {}}; }
        return resolve_locked();
    }
    auto prepared = inventory_->prepare(request, access);
    if (!prepared.changes) return prepared.result;
    try {
        auto waiting = std::make_unique<Waiting>();
        waiting->changes = prepared.changes;
        waiting->target = inventory_->checkpoint_after(prepared.changes);
        waiting_ = std::move(waiting);
    } catch (...) { inventory_->abort(prepared.changes); throw; }
    SaveOutcome outcome;
    try { outcome = store_->save(version_, waiting_->target, waiting_->target.requests.back()); }
    catch (...) { outcome = SaveOutcome::Unknown; }
    return finish(outcome);
}
Result DurableInventory::finish(SaveOutcome outcome) {
    auto sequence = inventory_->snapshot_roots({}).sequence;
    if (outcome == SaveOutcome::Unknown) return {Error::Pending, sequence, {}};
    if (outcome == SaveOutcome::Fenced) { fenced_ = true; return {Error::EpochMismatch, sequence, {}}; }
    if (outcome == SaveOutcome::Aborted) {
        inventory_->abort(waiting_->changes); waiting_.reset();
        return {Error::StorageUnavailable, sequence, {}};
    }
    auto result = inventory_->commit(waiting_->changes);
    const auto& saved = waiting_->target.requests.back().result;
    // If this invariant fails after a DB commit, stop writing and recover from DB.
    if (result.code != saved.code || result.sequence != saved.sequence || result.created != saved.created) {
        fenced_ = true;
        return {Error::InvalidState, sequence, {}};
    }
    ++version_; waiting_.reset();
    return result;
}
Result DurableInventory::resolve() {
    std::lock_guard lock(mutex_);
    return resolve_locked();
}
Result DurableInventory::resolve_locked() {
    auto sequence = inventory_->snapshot_roots({}).sequence;
    if (fenced_) return {Error::EpochMismatch, sequence, {}};
    if (!waiting_) return {Error::InvalidRequest, sequence, {}};
    try {
        auto loaded = store_->inspect();
        if (loaded.checkpoint.epoch != epoch_) return finish(SaveOutcome::Fenced);
        if (loaded.version == version_) return finish(SaveOutcome::Aborted);
        if (loaded.version == version_ + 1 &&
            encode_checkpoint(loaded.checkpoint) == encode_checkpoint(waiting_->target))
            return finish(SaveOutcome::Committed);
        return finish(SaveOutcome::Fenced);
    } catch (...) { return {Error::Pending, sequence, {}}; }
}
}
