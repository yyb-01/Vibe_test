#include "durable.hpp"

namespace astra {
std::vector<RecordedFire> Inventory::recorded_fires() const {
    std::lock_guard lock(mutex_); std::vector<RecordedFire> result;
    // ponytail: scan at most 65,536 records on session startup; index shots if startup profiling requires it.
    for (const auto& [key, record] : records_) {
        if (!record.result.applied() || key.second.hi != fire_request_namespace) continue;
        auto request = decode(record.payload);
        if (request.operation == Operation::Fire)
            result.push_back({key.first, request.moves[1].item, *request.shot, record.result.sequence, request.interactionLease});
    }
    return result;
}
std::vector<RecordedFire> DurableInventory::recorded_fires() {
    std::lock_guard lock(mutex_); require(!fenced_, Error::EpochMismatch);
    return inventory_->recorded_fires();
}
}
