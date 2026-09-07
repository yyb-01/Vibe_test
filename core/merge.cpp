#include "mutation.hpp"

namespace astra {
void merge_stack(const Catalog& catalog, World& w, const MoveEntry& m) {
    require(w.containers.at(m.target).kind != PlaceKind::World, Error::InvalidPlacement);
    Id target;
    for (const auto& [id, p] : w.placements) {
        if (p.container == m.target && p.x == m.x && p.y == m.y && p.socketId == m.socketId) {
            require(!target && p.rotation == m.rotation, Error::InvalidPlacement);
            target = id;
        }
    }
    require(bool(target) && target != m.item, Error::InvalidPlacement);
    auto& src = w.items.at(m.item);
    auto& dst = w.items.at(target);
    const auto& def = catalog.at(src.defId);
    require(src.defId == dst.defId && !def.containerDefId && !def.partDefId, Error::Incompatible);
    require(src.durability == dst.durability && src.contamination == dst.contamination &&
            src.wetness == dst.wetness && src.temperatureOffset == dst.temperatureOffset &&
            src.extraIndex == UINT32_MAX && dst.extraIndex == UINT32_MAX, Error::Incompatible);
    require(m.quantity <= def.maxStack - dst.quantity, Error::InvalidQuantity);
    bump(src.revision); bump(dst.revision);
    src.quantity -= m.quantity; dst.quantity += m.quantity;
    if (!src.quantity) { src.flags |= deleted; w.placements.erase(m.item); }
}
}
