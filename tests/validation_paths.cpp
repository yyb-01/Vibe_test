#include "scenario.hpp"

void validation_paths() {
    auto world = seed();
    add_item(world, 105, 1, 2, 40, 1);
    validate(catalog(), world);
    CHECK(world.containers.at(id(40)).state.subtreeMassG == 120);
    CHECK(world.containers.at(id(10)).state.subtreeMassG == 1120);
    // Reusing paths must be limited to one validation: the bag can change roots.
    auto& bag = world.placements.at(id(102));
    bag.container = id(20); bag.x = 4;
    validate(catalog(), world);
    CHECK(world.containers.at(id(10)).state.subtreeMassG == 500);
    CHECK(world.containers.at(id(20)).state.subtreeMassG == 3620);
    CHECK(world.containers.at(id(40)).state.subtreeMassG == 120);
    auto before = world;
    verify_world(catalog(), world);
    CHECK(world == before);
    auto corrupt = world;
    corrupt.containers.at(id(40)).state.usedVolumeMl = 0;
    auto unchanged = corrupt;
    rejects([&] { verify_world(catalog(), corrupt); }, Error::InvalidState);
    CHECK(corrupt == unchanged);
    auto missing = world;
    missing.placements.at(id(100)).container = id(999);
    rejects([&] { validate(catalog(), missing); }, Error::InvalidState);
    bag.container = id(40);
    rejects([&] { validate(catalog(), world); }, Error::CycleDetected);
}
