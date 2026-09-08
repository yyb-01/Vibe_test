#include "durable.hpp"

namespace astra {
Result DurableInventory::close() {
    std::lock_guard lock(mutex_);
    auto sequence = inventory_->snapshot_roots({}).sequence;
    closing_ = true;
    if (closed_) return {Error::Ok, sequence, {}};
    if (fenced_) return {Error::EpochMismatch, sequence, {}};
    if (waiting_) {
        auto resolved = resolve_locked();
        // A known rollback is settled too; an unknown outcome keeps the lock.
        if (waiting_ || fenced_) return resolved;
        sequence = inventory_->snapshot_roots({}).sequence;
    }
    try { store_->close(); }
    catch (const Violation& e) {
        if (e.code == Error::EpochMismatch) fenced_ = true;
        return {e.code, sequence, {}};
    } catch (...) { return {Error::StorageUnavailable, sequence, {}}; }
    closed_ = true;
    return {Error::Ok, sequence, {}};
}
}
