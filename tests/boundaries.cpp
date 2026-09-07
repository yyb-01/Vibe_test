#include "scenario.hpp"

void grid_and_tree_boundaries() {
    auto defs = catalog(); defs.at(1).gridW = 32;
    World w; auto c = container(10); c.state.width = 32; c.state.height = 1;
    w.containers.emplace(id(10), c);
    add_item(w, 100, 1, 1, 10);
    Inventory fullWidth(defs, w, 1, 1);
    CHECK(fullWidth.snapshot()->containers.at(id(10)).state.entryCount == 1);
    w.placements.at(id(100)).x = 1;
    rejects([&] { Inventory bad(defs, w, 1, 1); }, Error::InvalidPlacement);

    w = {}; c = container(10); c.kind = PlaceKind::Slot; c.state.width = 2; c.state.height = 1;
    w.containers.emplace(id(10), c);
    add_item(w, 100, 1, 1, 10); w.placements.at(id(100)).socketId = 1;
    add_item(w, 101, 1, 1, 10); w.placements.at(id(101)).socketId = 2;
    Inventory slots(catalog(), w, 1, 1);
    w.placements.at(id(101)).socketId = 1;
    rejects([&] { Inventory bad(catalog(), w, 1, 1); }, Error::InvalidPlacement);

    w = seed(); std::uint64_t parent = 40;
    for (unsigned i = 0; i < 3; ++i) {
        add_item(w, 200 + i, 2, 1, parent, 0, 1);
        w.containers.emplace(id(50 + i), container(50 + i, id(200 + i)));
        parent = 50 + i;
    }
    Inventory depth4(catalog(), w, 1, 1);
    CHECK(depth4.snapshot()->containers.at(id(52)).state.depth == 4);
    add_item(w, 203, 2, 1, 52);
    w.containers.emplace(id(53), container(53, id(203)));
    rejects([&] { Inventory bad(catalog(), w, 1, 1); }, Error::DepthExceeded);
}

void overflow_and_state() {
    auto defs = catalog();
    defs.at(1).massG = defs.at(1).maxStack = UINT32_MAX; defs.at(1).outerVolumeMl = 0;
    World w; auto c = container(10); c.maxMassG = UINT64_MAX;
    w.containers.emplace(id(10), c); add_item(w, 100, 1, UINT32_MAX, 10);
    Inventory huge(defs, w, 1, 1);
    CHECK(huge.snapshot()->containers.at(id(10)).state.subtreeMassG == std::uint64_t(UINT32_MAX) * UINT32_MAX);
    add_item(w, 101, 1, UINT32_MAX, 10, 1);
    rejects([&] { Inventory bad(defs, w, 1, 1); }, Error::CapacityExceeded);
    w = seed(); w.placements.erase(id(100));
    rejects([&] { Inventory bad(catalog(), w, 1, 1); }, Error::InvalidState);
    w = seed(); w.items.at(id(100)).flags = deleted;
    rejects([&] { Inventory bad(catalog(), w, 1, 1); }, Error::InvalidState);
}
