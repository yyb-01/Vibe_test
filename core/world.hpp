#pragma once
#include "types.hpp"
#include <map>
#include <memory>

namespace astra {
using Catalog = std::map<std::uint32_t, ItemDef>;
struct Container {
    ContainerState state;
    std::uint64_t maxMassG{UINT64_MAX}, allowedClasses{UINT64_MAX};
    PlaceKind kind{PlaceKind::Grid};
    bool operator==(const Container&) const = default;
};
struct World {
    std::map<Id, ItemState> items;
    std::map<Id, Container> containers;
    std::map<Id, Placement> placements;
    bool operator==(const World&) const = default;
};
using RootViews = std::map<Id, std::shared_ptr<const World>>;
struct RootSnapshot {
    std::uint64_t sequence{};
    RootViews roots; // Active rows only; all selected roots observed atomically.
};
}
