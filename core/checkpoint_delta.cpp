#include "inventory.hpp"
#include "checkpoint_delta.hpp"

namespace astra {
CheckpointDelta Inventory::checkpoint_delta(const std::shared_ptr<const WriteSet>& changes) const {
    std::lock_guard lock(mutex_);
    require(bool(changes) && pending_.size() == 1, Error::InvalidState);
    auto found = pending_.find(changes->account);
    require(found != pending_.end() && found->second.changes == changes, Error::InvalidRequest);
    return {*changes, origin_, sequence_ + (changes->outcome.applied() ? 1 : 0), nextId_, nextEvent_};
}
SavedRequest delta_record(const CheckpointDelta& delta) {
    const auto& c = delta.changes;
    auto result = c.outcome; result.sequence = delta.sequence;
    return {c.account, c.requestId, c.actionSeq, c.payload, result};
}
template<class T> static void patch(std::map<Id, T>& rows, const std::map<Id, RowChange<T>>& changes) {
    for (const auto& [id, change] : changes) {
        require(change.before || change.after, Error::InvalidState);
        auto found = rows.find(id);
        require(change.before ? found != rows.end() && found->second == *change.before : found == rows.end(),
                Error::InvalidState);
        if (change.after) rows.insert_or_assign(id, *change.after);
        else rows.erase(id);
    }
}
void apply_checkpoint_delta(Checkpoint& target, const CheckpointDelta& delta) {
    const auto& c = delta.changes;
    require(c.epoch == target.epoch && delta.origin == target.origin &&
            delta.nextId >= target.nextId && delta.nextEvent >= target.nextEvent &&
            delta.sequence == target.sequence + (c.outcome.applied() ? 1 : 0), Error::InvalidState);
    require(c.outcome.applied() || (c.items.empty() && c.containers.empty() && c.placements.empty()), Error::InvalidState);
    patch(target.world.items, c.items);
    patch(target.world.containers, c.containers);
    patch(target.world.placements, c.placements);
    target.sequence = delta.sequence; target.nextId = delta.nextId; target.nextEvent = delta.nextEvent;
    target.requests.push_back(delta_record(delta));
    validate_checkpoint(target);
}
}
