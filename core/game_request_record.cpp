#include "durable.hpp"
namespace astra {
bool Inventory::expired_input(Id account,Id requestId) const{
    std::lock_guard lock(mutex_);auto journal=retiredInputs_.find(account);
    if(journal==retiredInputs_.end())return false;auto floor=journal->second.floors.find(requestId.hi);
    return floor!=journal->second.floors.end()&&floor->second&&requestId.lo<=floor->second;
}
std::optional<Request> Inventory::recorded_request(Id account,Id requestId) const {
    std::lock_guard lock(mutex_);require(account&&requestId,Error::NotAccessible);
    auto found=records_.find({account,requestId});
    if(found!=records_.end())return decode(found->second.payload);
    auto p=pending_.find(account);
    if(p!=pending_.end()&&p->second.changes->requestId==requestId)return decode(p->second.changes->payload);
    return {};
}
std::optional<Request> DurableInventory::recorded_request(Id account,Id requestId) {
    std::lock_guard lock(mutex_);require(!fenced_,Error::EpochMismatch);
    return inventory_->recorded_request(account,requestId);
}
}
