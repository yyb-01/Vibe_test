#include "durable.hpp"

namespace astra {
std::optional<Request> Inventory::recorded_fire(Id account, std::uint32_t fireSeq) const {
    std::lock_guard lock(mutex_);
    require(bool(account), Error::NotAccessible);
    Id id{fire_request_namespace, fireSeq};
    const std::vector<std::uint8_t>* payload = nullptr;
    if (auto found = records_.find({account, id}); found != records_.end()) payload = &found->second.payload;
    else if (auto pending = pending_.find(account); pending != pending_.end() && pending->second.changes->requestId == id)
        payload = &pending->second.changes->payload;
    if (!payload) return {};
    auto request = decode(*payload);
    require(request.operation == Operation::Fire, Error::IdempotencyMismatch);
    return request;
}
std::optional<Request> DurableInventory::recorded_fire(Id account, std::uint32_t fireSeq) {
    std::lock_guard lock(mutex_);
    require(!fenced_, Error::EpochMismatch);
    return inventory_->recorded_fire(account, fireSeq);
}
}
