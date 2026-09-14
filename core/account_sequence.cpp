#include "inventory.hpp"

namespace astra {
std::uint64_t Inventory::next_action_sequence(Id account) const {
    std::lock_guard lock(mutex_);
    require(bool(account), Error::NotAccessible);
    auto found = accountSeq_.find(account);
    auto previous = found == accountSeq_.end() ? 0 : found->second;
    require(previous < revision_limit, Error::LimitExceeded);
    return previous + 1;
}
}
