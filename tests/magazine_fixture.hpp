#pragma once
#include "fire_scenario.hpp"
#include "magazine.hpp"
#include <array>

inline Catalog magazine_catalog() {
    auto cat = fire_catalog(); auto mag = cat.at(2);
    mag.id = 4; mag.massG = 100; mag.outerVolumeMl = 100; mag.gridW = mag.gridH = 1;
    mag.partDefId = 2; cat.emplace(4, mag);
    auto tracer = cat.at(1); tracer.id = 5; cat.emplace(5, tracer);
    return cat;
}
inline World magazine_seed() {
    auto w = fire_seed(); w.items.at(id(100)).quantity = 0;
    w.items.at(id(100)).flags |= deleted; w.placements.erase(id(100));
    auto mount = container(52, id(104)); mount.kind = PlaceKind::Slot;
    mount.state.width = mount.state.height = 1; w.containers.emplace(id(52), mount);
    add_item(w, 108, 4, 1, 52); w.placements.at(id(108)).socketId = 1;
    auto mag = container(53, id(108)); mag.kind = PlaceKind::Slot; mag.state.flags = magazine_container;
    mag.state.width = mag.state.height = 6; mag.state.capacityMl = 30; w.containers.emplace(id(53), mag);
    for (auto [n, def, qty, socket, wet] : {std::array{110, 1, 2, 1, 10}, {109, 5, 1, 4, 0}, {111, 1, 2, 6, 20}}) {
        add_item(w, n, def, qty, 53); w.placements.at(id(n)).socketId = socket;
        w.items.at(id(n)).wetness = wet;
    }
    return w;
}
inline Checkpoint magazine_checkpoint() { return Inventory(magazine_catalog(), magazine_seed(), 1, 1).checkpoint(); }
