#pragma once
#include "scenario.hpp"
#include "fire_commit.hpp"
#include "chamber.hpp"

inline Catalog fire_catalog() { auto c = catalog(); c.at(3).containerDefId = 2; return c; }
inline void add_chamber(World& w, std::uint64_t chamberId, Id weapon) {
    auto c = container(chamberId, weapon); c.kind = PlaceKind::Slot;
    c.state.width = c.state.height = 1; c.state.capacityMl = 5; c.state.flags = chamber_container;
    w.containers.emplace(id(chamberId), c);
}
inline World fire_seed() {
    auto w = seed(); add_chamber(w, 50, id(104)); w.items.at(id(100)).quantity = 1;
    auto& p = w.placements.at(id(100)); p.container = id(50); p.kind = PlaceKind::Slot; p.socketId = 1;
    add_item(w, 106, 1, 19, 10); return w;
}
inline Checkpoint fire_checkpoint() { return Inventory(fire_catalog(), fire_seed(), 1, 1).checkpoint(); }
struct FireScenario {
    Inventory inventory{fire_catalog(), fire_seed(), 1, 1};
    Access access{{77, 1}, 1, 99, {id(10), id(20), id(30)}};
};

inline Request shot_request(const World& world) {
    auto ammo = move(world, id(100), world.placements.at(id(100)).container, 0); ammo.quantity = 1;
    auto weapon = move(world, id(104), world.placements.at(id(104)).container, 0);
    Request request{{fire_request_namespace, 1}, 1, Operation::Fire, {ammo, weapon}, 0, 99};
    ShotData shot;
    shot.intent = {1, 1, 100, 0, 7, 2, 3, 0, 0, trigger_on, 0};
    shot.launch = {{}, {900000000, 0, 0}}; shot.massMg = 8000; shot.effectiveQ16 = 100 * 65536;
    shot.ammoDef = 1; shot.visualSeed = 9; shot.durabilityCost = 5;
    request.shot = shot; return request;
}
inline FireAuthority shot_authority() {
    FireAuthority state;
    state.account = state.weaponOwner = {77, 1}; state.weaponNetId = 7; state.generation = 2;
    state.assemblyRevision = 3; state.nowQ16 = 100 * 65536; state.minIntervalQ16 = 65536;
    state.alive = state.chambered = state.triggerReady = state.poseAvailable = state.muzzleClear = true;
    state.clockReady = true; return state;
}
