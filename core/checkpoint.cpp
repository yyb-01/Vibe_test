#include "inventory.hpp"
#include <algorithm>

namespace astra {
void validate_checkpoint(const Checkpoint& c) {
    require(c.epoch && c.epoch <= revision_limit && c.origin && c.origin <= revision_limit, Error::InvalidState);
    require(c.sequence <= revision_limit && c.nextId && c.nextId <= revision_limit &&
            c.nextEvent && c.nextEvent <= revision_limit + 1, Error::InvalidState);
    auto checked = c.world;
    validate(c.catalog, checked);
    require(checked == c.world && c.requests.size() <= 65536, Error::InvalidState);
    for (const auto& [id, item] : c.world.items) {
        if (id.hi == c.origin) require(id.lo < c.nextId && item.birthEvent < c.nextEvent, Error::InvalidState);
    }
    for (const auto& [id, container] : c.world.containers) {
        if (id.hi == c.origin) require(id.lo < c.nextId, Error::InvalidState);
        (void)container;
    }
    std::set<std::pair<Id, Id>> keys;
    std::map<Id, std::set<std::uint64_t>> accounts;
    std::set<std::uint64_t> sequences;
    for (const auto& record : c.requests) {
        require(bool(record.account) && keys.emplace(record.account, record.requestId).second, Error::InvalidState);
        auto request = decode(record.payload);
        require(encode(request) == record.payload && request.id == record.requestId &&
                request.actionSeq == record.actionSeq && record.actionSeq && record.actionSeq <= revision_limit,
                Error::InvalidState);
        require(accounts[record.account].insert(record.actionSeq).second && accounts.size() <= 64, Error::InvalidState);
        require(static_cast<unsigned>(record.result.code) <= static_cast<unsigned>(Error::LimitExceeded) &&
                record.result.sequence <= c.sequence, Error::InvalidState);
        if (record.result.applied()) {
            require(record.result.sequence && sequences.insert(record.result.sequence).second, Error::InvalidState);
            require(bool(record.result.created) == (request.operation == Operation::Split), Error::InvalidState);
            if (record.result.created) require(c.world.items.contains(record.result.created), Error::InvalidState);
        } else require(!record.result.created, Error::InvalidState);
    }
    require(sequences.size() == c.sequence, Error::InvalidState);
    for (const auto& [account, actions] : accounts) {
        (void)account;
        require(*actions.rbegin() == actions.size(), Error::InvalidState);
    }
}
Inventory::Inventory(Checkpoint c) : Inventory(c.catalog, c.world, c.epoch, c.origin) {
    validate_checkpoint(c);
    sequence_ = c.sequence; nextId_ = c.nextId; nextEvent_ = c.nextEvent;
    for (auto& request : c.requests) {
        accountSeq_[request.account] = std::max(accountSeq_[request.account], request.actionSeq);
        records_.emplace(std::pair{request.account, request.requestId},
                        Record{std::move(request.payload), request.result, {}});
    }
}
Checkpoint Inventory::checkpoint_locked() const {
    Checkpoint c{catalog_, world_, epoch_, origin_, sequence_, nextId_, nextEvent_, {}};
    c.requests.reserve(records_.size());
    for (const auto& [key, record] : records_) {
        auto request = decode(record.payload);
        c.requests.push_back({key.first, key.second, request.actionSeq, record.payload, record.result});
    }
    return c;
}
Checkpoint Inventory::checkpoint() const {
    std::lock_guard lock(mutex_);
    return checkpoint_locked();
}
Checkpoint Inventory::checkpoint_after(const std::shared_ptr<const WriteSet>& changes) const {
    std::lock_guard lock(mutex_);
    require(bool(changes) && pending_.size() == 1, Error::InvalidState);
    auto found = pending_.find(changes->account);
    require(found != pending_.end() && found->second.changes == changes, Error::InvalidRequest);
    auto c = checkpoint_locked();
    auto result = changes->outcome;
    result.sequence = c.sequence + (result.applied() ? 1 : 0);
    if (result.applied()) {
        for (const auto& [id, change] : changes->items) {
            if (change.after) c.world.items.insert_or_assign(id, *change.after); else c.world.items.erase(id);
        }
        for (const auto& [id, change] : changes->containers) {
            if (change.after) c.world.containers.insert_or_assign(id, *change.after); else c.world.containers.erase(id);
        }
        for (const auto& [id, change] : changes->placements) {
            if (change.after) c.world.placements.insert_or_assign(id, *change.after); else c.world.placements.erase(id);
        }
        c.sequence = result.sequence;
    }
    c.requests.push_back({changes->account, changes->requestId, changes->actionSeq, changes->payload, result});
    return c;
}
}
