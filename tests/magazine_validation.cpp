#include "magazine_fixture.hpp"

void magazine_validation() {
    auto cat = magazine_catalog(); auto good = magazine_seed();
    auto bad = good; bad.items.at(id(109)).quantity = 3;
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidQuantity);
    bad = good; bad.items.at(id(109)).defId = 2;
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::Incompatible);
    bad = good; bad.containers.at(id(53)).state.flags |= chamber_container;
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidState);
    bad = good; bad.containers.at(id(53)).state.ownerItem = id(102);
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidState);
    bad = good; bad.containers.emplace(id(54), bad.containers.at(id(53)));
    bad.containers.at(id(54)).state.id = id(54);
    rejects([&] { Inventory invalid(cat, bad, 1, 1); }, Error::InvalidState);
    bad = good; bad.placements.at(id(108)) = {id(108), id(20), 0, 4};
    bad.placements.at(id(108)).kind = PlaceKind::Grid;
    Inventory detached(cat, bad, 1, 1);
    CHECK(magazine_state(*detached.snapshot(), id(108)).rounds == 5);
    rejects([&] { feed_request(*detached.snapshot(), id(104), id(108), {88, 1}, 1, 99); }, Error::NotAccessible);
}
