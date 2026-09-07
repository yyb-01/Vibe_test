#include "inventory.hpp"

namespace astra {
std::vector<Id> ancestry(const World& world, Id id) {
    std::vector<Id> chain;
    std::set<Id> seen;
    for (;;) {
        require(seen.insert(id).second, Error::CycleDetected);
        require(chain.size() < 5, Error::DepthExceeded);
        auto container = world.containers.find(id);
        require(container != world.containers.end(), Error::InvalidState);
        chain.push_back(id);
        auto owner = container->second.state.ownerItem;
        if (!owner) return chain;
        auto item = world.items.find(owner);
        require(item != world.items.end() && !(item->second.flags & deleted), Error::InvalidState);
        auto place = world.placements.find(owner);
        require(place != world.placements.end(), Error::InvalidState);
        id = place->second.container;
    }
}
}
