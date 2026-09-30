#include "fire_scenario.hpp"

void chamber_validation_checks() {
    auto world = fire_seed(); auto cat = fire_catalog();
    CHECK(chamber_state(world, id(104)).round == id(100));
    auto bad = world; bad.containers.at(id(50)).state.width = 2;
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidState);
    bad = world; add_chamber(bad, 51, id(104));
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidState);
    bad = world; bad.items.at(id(100)).quantity = 2;
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidQuantity);
    bad = world; bad.items.at(id(100)).defId = 2;
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::Incompatible);
    bad = world; bad.items.at(id(100)).extraIndex = 0;
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::Incompatible);
    bad = world; bad.containers.at(id(50)).state.ownerItem = id(102);
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidState);
    Inventory loose(cat, seed(), 1, 1); auto request = shot_request(*loose.snapshot());
    Access access{{77, 1}, 1, 99, {id(10), id(20)}};
    CHECK(loose.apply(request, approve_fire(request, shot_authority(), access)).code == Error::NotAccessible);
    CHECK(loose.snapshot()->items.at(id(100)).quantity == 20);
}
