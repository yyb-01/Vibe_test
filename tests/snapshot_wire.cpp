#include "scenario.hpp"
#include "snapshot.hpp"

void snapshot_wire() {
    Scenario s; auto view = s.inventory.snapshot_roots({id(10)});
    auto part = std::make_shared<World>(*view.roots.at(id(10)));
    part->items.at(id(100)).birthEvent = 9876;
    part->items.at(id(100)).extraIndex = 123;
    view.roots.at(id(10)) = part;
    auto bytes = encode_view(view); auto world = decode_view(bytes, catalog());
    CHECK(world.items.size() == 4 && world.items.contains(id(103)) && !world.items.contains(id(104)));
    CHECK(world.items.at(id(100)).birthEvent == 0 && world.items.at(id(100)).extraIndex == UINT32_MAX);
    CHECK(world.containers.size() == 2 && !world.containers.contains(id(20)));
    for (std::size_t n = 0; n < bytes.size(); ++n)
        rejects([&] { decode_view({bytes.begin(), bytes.begin() + n}, catalog()); }, Error::InvalidRequest);
    auto bad = bytes; bad[4] = 17;
    rejects([&] { decode_view(bad, catalog()); }, Error::InvalidRequest);
    bad = bytes; bad[36 + 56] = 1;
    rejects([&] { decode_view(bad, catalog()); }, Error::InvalidRequest);
    bytes.push_back(0);
    rejects([&] { decode_view(bytes, catalog()); }, Error::InvalidRequest);
}
