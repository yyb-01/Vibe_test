#include "inventory.hpp"
#include <algorithm>

namespace astra {
Inventory::Inventory(Catalog catalog, World initial, std::uint64_t epoch, std::uint64_t idOrigin)
    : catalog_(std::move(catalog)), epoch_(epoch), origin_(idOrigin) {
    require(epoch && epoch <= revision_limit && idOrigin, Error::InvalidState);
    validate(catalog_, initial);
    for (const auto& [id, value] : initial.items) {
        (void)value;
        if (id.hi == origin_) { require(id.lo < revision_limit, Error::LimitExceeded); nextId_ = std::max(nextId_, id.lo + 1); }
    }
    for (const auto& [id, value] : initial.containers) {
        (void)value;
        if (id.hi == origin_) { require(id.lo < revision_limit, Error::LimitExceeded); nextId_ = std::max(nextId_, id.lo + 1); }
    }
    roots_ = partition_roots(initial);
    world_ = std::move(initial);
}
std::shared_ptr<const World> Inventory::snapshot() const {
    std::lock_guard lock(mutex_);
    if (auto cached = flatSnapshot_.lock()) return cached;
    auto copy = std::make_shared<const World>(world_);
    flatSnapshot_ = copy;
    return copy;
}
RootSnapshot Inventory::snapshot_roots(const std::set<Id>& roots) const {
    std::lock_guard lock(mutex_);
    RootSnapshot view{sequence_, {}};
    for (auto root : roots) {
        auto found = roots_.find(root);
        require(found != roots_.end(), Error::InvalidState);
        view.roots.emplace(root, found->second);
    }
    return view;
}
Result Inventory::apply(const Request& r, const Access& access) {
    std::lock_guard lock(mutex_);
    // A synchronous caller must not publish work already owned by a worker.
    if (pending_.contains(access.account)) return prepare_locked(r, access).result;
    auto prepared = prepare_locked(r, access);
    return prepared.changes ? commit_locked(prepared.changes) : prepared.result;
}
Preparation Inventory::prepare(const Request& r, const Access& access) {
    std::lock_guard lock(mutex_);
    return prepare_locked(r, access);
}
Preparation Inventory::prepare_locked(const Request& r, const Access& access) {
    try {
        require(access.epoch == epoch_, Error::EpochMismatch);
        require(bool(access.account), Error::NotAccessible);
        auto bytes = encode(r);
        auto key = std::pair{access.account, r.id};
        if (auto found = records_.find(key); found != records_.end()) {
            require(found->second.payload == bytes, Error::IdempotencyMismatch);
            return {found->second.result, {}};
        }
        if (auto found = pending_.find(access.account); found != pending_.end()) {
            const auto& changes = found->second.changes;
            if (changes->requestId == r.id) {
                require(changes->payload == bytes, Error::IdempotencyMismatch);
                return {{Error::Pending, sequence_, {}}, changes};
            }
            return {{Error::Busy, sequence_, {}}, {}};
        }
        require(records_.size() < 65536 && (accountSeq_.contains(access.account) || accountSeq_.size() < 64), Error::LimitExceeded);
        std::size_t newAccounts = 0, reservedItems = 0, reservedCommits = 0;
        for (const auto& [id, pending] : pending_) {
            (void)id;
            if (!pending.account.empty()) ++newAccounts;
            if (pending.changes->outcome.created) ++reservedItems;
            if (pending.changes->outcome.applied()) ++reservedCommits;
        }
        if (records_.size() + pending_.size() >= 65536 ||
            (!accountSeq_.contains(access.account) && accountSeq_.size() + newAccounts >= 64))
            return {{Error::Busy, sequence_, {}}, {}};
        auto account = accountSeq_.find(access.account);
        auto previousSeq = account == accountSeq_.end() ? 0 : account->second;
        require(r.actionSeq == previousSeq + 1 && r.actionSeq <= revision_limit, Error::SequenceMismatch);
        auto changes = std::make_shared<WriteSet>();
        changes->account = access.account; changes->requestId = r.id;
        changes->epoch = epoch_; changes->actionSeq = r.actionSeq;
        changes->payload = bytes;
        Result result;
        std::set<Id> roots;
        Pending pending;
        try {
            require(r.baseline <= sequence_, Error::RevisionConflict);
            check_request(world_, r, access);
            for (const auto& m : r.moves)
                for (auto endpoint : {m.source, m.target})
                    roots.insert(ancestry(world_, endpoint).back());
            for (const auto& [id, pending] : pending_) {
                (void)id;
                for (auto root : pending.changes->roots)
                    if (roots.contains(root)) return {{Error::Busy, sequence_, {}}, {}};
            }
            require(sequence_ < revision_limit && nextEvent_ <= revision_limit, Error::LimitExceeded);
            if (reservedCommits >= revision_limit - sequence_)
                return {{Error::Busy, sequence_, {}}, {}};
            if (r.operation == Operation::Split) {
                require(nextId_ < revision_limit && world_.items.size() < 65536, Error::LimitExceeded);
                if (world_.items.size() + reservedItems >= 65536)
                    return {{Error::Busy, sequence_, {}}, {}};
            }
            auto before = copy_roots(roots_, roots);
            auto next = before;
            Id created{origin_, nextId_};
            mutate(catalog_, next, r, created, nextEvent_);
            describe_changes(before, next, *changes);
            pending.roots = partition_roots(next);
            for (const auto& [id, change] : changes->items)
                if (change.after) pending.rows.items.emplace(id, *change.after);
            for (const auto& [id, change] : changes->containers)
                if (change.after) pending.rows.containers.emplace(id, *change.after);
            for (const auto& [id, change] : changes->placements)
                if (change.after) pending.rows.placements.emplace(id, *change.after);
            if (r.operation == Operation::Split) result.created = created;
            changes->event = nextEvent_;
        } catch (const Violation& error) {
            result.code = error.code;
            // A final rejection has no state to protect while its result waits.
            roots.clear();
            pending.rows = {}; pending.roots.clear();
            changes->items.clear(); changes->containers.clear(); changes->placements.clear();
        }
        changes->outcome = result;
        changes->roots.assign(roots.begin(), roots.end());

        // Allocate result/account map nodes before exposing the prepared handle.
        RecordMap recordNodes;
        recordNodes.emplace(key, Record{std::move(bytes), result, changes});
        pending.record = recordNodes.extract(key);
        if (account == accountSeq_.end()) {
            AccountMap accountNodes;
            accountNodes.emplace(access.account, r.actionSeq);
            pending.account = accountNodes.extract(access.account);
        }
        pending.changes = std::move(changes);
        auto inserted = pending_.emplace(access.account, std::move(pending)).first;
        // IDs exposed to a worker are never reused, even after a definite abort.
        if (result.created) ++nextId_;
        if (result.applied()) ++nextEvent_;
        return {{Error::Pending, sequence_, {}}, inserted->second.changes};
    } catch (const Violation& error) { return {{error.code, sequence_, {}}, {}}; }
}
bool Inventory::abort(const std::shared_ptr<const WriteSet>& changes) {
    std::lock_guard lock(mutex_);
    if (!changes) return false;
    auto found = pending_.find(changes->account);
    if (found == pending_.end() || found->second.changes != changes) return false;
    pending_.erase(found);
    return true;
}
}
