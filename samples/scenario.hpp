#pragma once
#include "inventory.hpp"

using namespace astra;
inline Id id(std::uint64_t n) { return {1, n}; }
inline Catalog catalog() {
    ItemDef ammo; ammo.id = 1; ammo.massG = 10; ammo.outerVolumeMl = 5; ammo.maxStack = 100;
    ItemDef bag; bag.id = 2; bag.massG = 500; bag.outerVolumeMl = 2000;
    bag.gridW = bag.gridH = 2; bag.containerDefId = 1;
    ItemDef rifle; rifle.id = 3; rifle.massG = 3000; rifle.outerVolumeMl = 3000;
    rifle.gridW = 3; rifle.partDefId = 1;
    return {{1, ammo}, {2, bag}, {3, rifle}};
}
inline Container container(std::uint64_t n, Id owner = {}) {
    Container c;
    c.state.id = id(n); c.state.ownerItem = owner; c.state.width = c.state.height = 8;
    c.state.capacityMl = 50000; c.maxMassG = 50000;
    return c;
}
inline void add_item(World& w, std::uint64_t n, std::uint32_t def, std::uint32_t qty,
                     std::uint64_t target, std::uint16_t x = 0, std::uint16_t y = 0) {
    ItemState item; item.id = id(n); item.defId = def; item.quantity = qty;
    w.items.emplace(item.id, item);
    Placement p; p.item = item.id; p.container = id(target); p.x = x; p.y = y;
    p.kind = w.containers.at(id(target)).kind;
    w.placements.emplace(item.id, p);
}
inline World seed() {
    World w;
    for (auto n : {10, 20, 30}) w.containers.emplace(id(n), container(n));
    w.containers.at(id(30)).kind = PlaceKind::World;
    w.containers.emplace(id(40), container(40, id(102)));
    add_item(w, 100, 1, 20, 10);
    add_item(w, 101, 1, 30, 10, 1);
    add_item(w, 102, 2, 1, 10, 2);
    add_item(w, 103, 1, 10, 40);
    add_item(w, 104, 3, 1, 20);
    return w;
}
inline MoveEntry move(const World& w, Id item, Id target, std::uint16_t x = 4, std::uint16_t y = 0) {
    const auto& i = w.items.at(item);
    auto source = w.placements.at(item).container;
    return {item, source, target, i.revision, w.containers.at(source).state.revision,
            w.containers.at(target).state.revision, i.quantity, 0, x, y, 0};
}
struct Scenario {
    Inventory inventory{catalog(), seed(), 1, 1};
    Access access{{77, 1}, 1, 99, {id(10), id(20), id(30)}};
    std::uint64_t next{1};
    Request request(Operation op, std::vector<MoveEntry> moves) {
        auto sequence = next++;
        return {{88, sequence}, sequence, op, std::move(moves), 0, 99};
    }
};
