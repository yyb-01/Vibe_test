#include "mutation.hpp"
#include "fire_commit.hpp"
#include "chamber.hpp"

namespace astra {
Access approve_fire(const Request& request, const FireAuthority& authority, Access access) {
    require(request.operation == Operation::Fire && request.shot && access.account == authority.account,
        Error::NotAccessible);
    require(request.shot->effectiveQ16 == validate_fire_candidate(request.shot->intent, authority),
        Error::InvalidRequest);
    access.approvedFire = encode(request);
    return access;
}
void consume_shot(const Catalog& catalog, World& world, const Request& request) {
    const auto& shot = *request.shot;
    auto& ammo = world.items.at(request.moves[0].item);
    auto& weapon = world.items.at(request.moves[1].item);
    require(chamber_state(world, weapon.id).round == ammo.id && ammo.quantity == 1, Error::NotAccessible);
    const auto& definition = catalog.at(ammo.defId);
    require(ammo.defId == shot.ammoDef && !definition.containerDefId && !definition.partDefId &&
        ammo.extraIndex == UINT32_MAX && weapon.quantity == 1, Error::Incompatible);
    require(weapon.durability >= shot.durabilityCost && !ammo.reservedBy && !weapon.reservedBy, Error::NotAccessible);
    bump(ammo.revision); bump(weapon.revision);
    --ammo.quantity; weapon.durability -= shot.durabilityCost;
    if (!ammo.quantity) { ammo.flags |= deleted; world.placements.erase(ammo.id); }
}
}
