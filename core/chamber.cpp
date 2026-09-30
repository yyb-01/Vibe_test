#include "chamber.hpp"

namespace astra {
void validate_chambers(const Catalog& catalog, const World& w) {
    std::set<Id> owners;
    for (const auto& [id, c] : w.containers) {
        (void)id; if (!(c.state.flags & chamber_container)) continue;
        require(!(c.state.flags & magazine_container), Error::InvalidState);
        auto owner = w.items.find(c.state.ownerItem);
        require(owner != w.items.end() && catalog.contains(owner->second.defId), Error::InvalidState);
        const auto& d = catalog.at(owner->second.defId);
        require(c.kind == PlaceKind::Slot && c.state.width == 1 && c.state.height == 1 &&
            d.partDefId && d.containerDefId && owners.insert(c.state.ownerItem).second, Error::InvalidState);
    }
    for (const auto& [id, p] : w.placements) {
        auto c = w.containers.find(p.container);
        if (c == w.containers.end() || !(c->second.state.flags & chamber_container)) continue;
        require(w.items.contains(id) && catalog.contains(w.items.at(id).defId), Error::InvalidState);
        const auto& item = w.items.at(id); const auto& d = catalog.at(item.defId);
        require(item.quantity == 1, Error::InvalidQuantity);
        require(!d.containerDefId && !d.partDefId && item.extraIndex == UINT32_MAX, Error::Incompatible);
    }
}
Chamber chamber_state(const World& w, Id weapon) {
    Chamber result;
    for (const auto& [id, c] : w.containers)
        if (c.state.ownerItem == weapon && (c.state.flags & chamber_container)) {
            require(!result.container, Error::InvalidState); result.container = id;
        }
    // ponytail: scan at most 1,024 active rows in the selected root; index placements if profiling requires it.
    if (result.container) for (const auto& [id, p] : w.placements)
        if (p.container == result.container) { require(!result.round, Error::InvalidState); result.round = id; }
    return result;
}
Request chamber_request(const World& w, Id weapon, Id ammo, Id id, std::uint64_t seq, std::uint64_t lease) {
    auto chamber = chamber_state(w, weapon);
    require(bool(chamber.container) && !chamber.round && w.items.contains(ammo) && w.placements.contains(ammo), Error::NotAccessible);
    const auto& item = w.items.at(ammo); auto source = w.placements.at(ammo).container;
    MoveEntry move{ammo, source, chamber.container, item.revision, w.containers.at(source).state.revision,
                   w.containers.at(chamber.container).state.revision, 1, 1};
    return {id, seq, item.quantity == 1 ? Operation::Move : Operation::Split, {move}, 0, lease};
}
}
