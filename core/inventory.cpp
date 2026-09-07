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
    world_ = std::make_shared<const World>(std::move(initial));
}
std::shared_ptr<const World> Inventory::snapshot() const {
    std::lock_guard lock(mutex_);
    return world_;
}
Result Inventory::apply(const Request& r, const Access& access) {
    std::lock_guard lock(mutex_);
    try {
        require(access.epoch == epoch_, Error::EpochMismatch);
        require(bool(access.account), Error::NotAccessible);
        auto bytes = encode(r);
        auto key = std::pair{access.account, r.id};
        if (auto found = records_.find(key); found != records_.end()) {
            require(found->second.payload == bytes, Error::IdempotencyMismatch);
            return found->second.result;
        }
        require(records_.size() < 65536 && (accountSeq_.contains(access.account) || accountSeq_.size() < 64), Error::LimitExceeded);
        auto [account, inserted] = accountSeq_.try_emplace(access.account, 0);
        (void)inserted;
        require(r.actionSeq == account->second + 1 && r.actionSeq <= revision_limit, Error::SequenceMismatch);
        Result result{Error::Ok, sequence_, {}};
        std::shared_ptr<World> next;
        try {
            require(r.baseline <= sequence_, Error::RevisionConflict);
            check_request(*world_, r, access);
            require(sequence_ < revision_limit && nextId_ < revision_limit, Error::LimitExceeded);
            // ponytail: copy-on-write whole state; use affected-root write sets at world scale.
            next = std::make_shared<World>(*world_);
            Id created{origin_, nextId_};
            mutate(catalog_, *next, r, created, sequence_ + 1);
            result.sequence = sequence_ + 1;
            if (r.operation == Operation::Split) result.created = created;
        } catch (const Violation& error) { result.code = error.code; next.reset(); }
        records_.emplace(key, Record{std::move(bytes), result});
        account->second = r.actionSeq;
        if (next) { world_ = std::move(next); sequence_ = result.sequence; if (result.created) ++nextId_; }
        return result;
    } catch (const Violation& error) { return {error.code, sequence_, {}}; }
}
}
