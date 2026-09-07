#include "inventory.hpp"

namespace astra {
namespace {
template<class T>
void verify_rows(const std::map<Id, T>& rows, const std::map<Id, RowChange<T>>& changes) {
    for (const auto& [id, change] : changes) {
        auto found = rows.find(id);
        require(change.before ? found != rows.end() && found->second == *change.before
                              : found == rows.end(), Error::RevisionConflict);
    }
}
template<class T>
void publish_rows(std::map<Id, T>& rows, std::map<Id, T>& prepared,
                  const std::map<Id, RowChange<T>>& changes) {
    for (const auto& [id, change] : changes) {
        (void)change;
        rows.erase(id);
    }
    // Nodes and values were allocated during prepare. Id ordering cannot throw.
    rows.merge(prepared);
}
}
Result Inventory::commit(const std::shared_ptr<const WriteSet>& changes) {
    std::lock_guard lock(mutex_);
    return commit_locked(changes);
}
Result Inventory::commit_locked(const std::shared_ptr<const WriteSet>& changes) {
    if (!changes) return {Error::InvalidRequest, sequence_, {}};
    if (auto found = records_.find({changes->account, changes->requestId}); found != records_.end()) {
        if (found->second.handle.lock() == changes) return found->second.result;
    }
    auto found = pending_.find(changes->account);
    // Pointer identity prevents forged, aborted, or other-inventory handles.
    if (found == pending_.end() || found->second.changes != changes)
        return {Error::InvalidRequest, sequence_, {}};
    auto& pending = found->second;
    auto result = changes->outcome;
    if (result.applied()) {
        try {
            verify_rows(world_.items, changes->items);
            verify_rows(world_.containers, changes->containers);
            verify_rows(world_.placements, changes->placements);
            for (const auto& [root, view] : pending.roots) {
                (void)view;
                require(roots_.contains(root), Error::RevisionConflict);
            }
            require(sequence_ < revision_limit, Error::LimitExceeded);
        } catch (const Violation& error) {
            // Preserve the reservation for host inspection; never partly publish.
            return {error.code, sequence_, {}};
        }
    }
    result.sequence = sequence_ + (result.applied() ? 1 : 0);
    pending.record.mapped().result = result;
    records_.insert(std::move(pending.record));
    if (!pending.account.empty()) accountSeq_.insert(std::move(pending.account));
    else accountSeq_.find(changes->account)->second = changes->actionSeq;
    if (result.applied()) {
        publish_rows(world_.items, pending.rows.items, changes->items);
        publish_rows(world_.containers, pending.rows.containers, changes->containers);
        publish_rows(world_.placements, pending.rows.placements, changes->placements);
        for (auto& [root, view] : pending.roots) roots_.find(root)->second = std::move(view);
        sequence_ = result.sequence;
        // Legacy full snapshots are made lazily; old readers own independent copies.
        flatSnapshot_.reset();
    }
    pending_.erase(found);
    return result;
}
}
