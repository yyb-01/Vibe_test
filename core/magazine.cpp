#include "magazine.hpp"

namespace astra {
void validate_magazines(const Catalog& cat, const World& w) {
    std::set<Id> owners;
    std::map<Id, std::uint32_t> counts;
    for (const auto& [id, c] : w.containers) {
        if (!(c.state.flags & magazine_container)) continue;
        auto owner = w.items.find(c.state.ownerItem);
        require(owner != w.items.end() && cat.contains(owner->second.defId), Error::InvalidState);
        const auto& d = cat.at(owner->second.defId);
        require(!(c.state.flags & chamber_container) && c.kind == PlaceKind::Slot &&
            c.state.width && c.state.width <= c.state.height && c.state.height <= 32 &&
            d.partDefId && d.containerDefId && owners.insert(c.state.ownerItem).second, Error::InvalidState);
        counts.emplace(id, 0);
    }
    for (const auto& [id, p] : w.placements) {
        auto count = counts.find(p.container); if (count == counts.end()) continue;
        require(w.items.contains(id) && cat.contains(w.items.at(id).defId), Error::InvalidState);
        const auto& item = w.items.at(id); const auto& d = cat.at(item.defId);
        require(!d.partDefId && !d.containerDefId && item.extraIndex == UINT32_MAX, Error::Incompatible);
        require(item.quantity <= w.containers.at(p.container).state.height - count->second, Error::InvalidQuantity);
        count->second += item.quantity;
    }
}
Magazine magazine_state(const World& w, Id magazine) {
    Magazine result;
    for (const auto& [id, c] : w.containers)
        if (c.state.ownerItem == magazine && (c.state.flags & magazine_container)) {
            require(!result.container, Error::InvalidState); result.container = id;
        }
    std::uint32_t first = UINT32_MAX;
    if (result.container) for (const auto& [id, p] : w.placements) {
        if (p.container != result.container) continue;
        require(w.items.contains(id), Error::InvalidState);
        auto quantity = w.items.at(id).quantity;
        require(quantity <= w.containers.at(result.container).state.height - result.rounds, Error::InvalidQuantity);
        result.rounds += quantity;
        if (p.socketId < first) { first = p.socketId; result.nextRound = id; }
    }
    return result;
}
Request feed_request(const World& w, Id weapon, Id magazine, Id id, std::uint64_t seq, std::uint64_t lease) {
    require(w.placements.contains(magazine), Error::NotAccessible);
    const auto& mount = w.containers.at(w.placements.at(magazine).container);
    require(mount.state.ownerItem == weapon && mount.kind == PlaceKind::Slot &&
        !(mount.state.flags & (chamber_container | magazine_container)), Error::NotAccessible);
    auto state = magazine_state(w, magazine);
    require(bool(state.nextRound), Error::NotAccessible);
    return chamber_request(w, weapon, state.nextRound, id, seq, lease);
}
}
