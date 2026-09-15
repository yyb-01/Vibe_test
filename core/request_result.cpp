#include "durable.hpp"

namespace astra {
std::optional<Result> Inventory::result_for(const Request& request, Id account) const {
    std::lock_guard lock(mutex_);
    try {
        require(bool(account), Error::NotAccessible);
        auto bytes = encode(request);
        if (auto r = records_.find({account, request.id}); r != records_.end()) {
            require(r->second.payload == bytes, Error::IdempotencyMismatch);
            return r->second.result;
        }
        if (auto p = pending_.find(account); p != pending_.end() && p->second.changes->requestId == request.id) {
            require(p->second.changes->payload == bytes, Error::IdempotencyMismatch);
            return Result{Error::Pending, sequence_, {}};
        }
        return {};
    } catch (const Violation& e) { return Result{e.code, sequence_, {}}; }
}
std::optional<Result> DurableInventory::result_for(const Request& request, Id account) {
    std::lock_guard lock(mutex_);
    if (fenced_) return Result{Error::EpochMismatch, inventory_->snapshot_roots({}).sequence, {}};
    auto result = inventory_->result_for(request, account);
    if (result && result->code == Error::Pending) return resolve_locked();
    return result;
}
}
