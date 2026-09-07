#include "inventory.hpp"

namespace astra {
RootViews partition_roots(const World& world) {
    std::map<Id, World> parts;
    std::map<Id, Id> containerRoots;
    for (const auto& [id, container] : world.containers) {
        auto root = ancestry(world, id).back();
        containerRoots.emplace(id, root);
        parts[root].containers.emplace(id, container);
    }
    for (const auto& [id, placement] : world.placements) {
        auto& part = parts.at(containerRoots.at(placement.container));
        part.placements.emplace(id, placement);
        part.items.emplace(id, world.items.at(id));
    }
    RootViews views;
    for (auto& [root, part] : parts)
        views.emplace(root, std::make_shared<const World>(std::move(part)));
    return views;
}
World copy_roots(const RootViews& views, const std::set<Id>& roots) {
    World selected;
    for (auto root : roots) {
        auto found = views.find(root);
        require(found != views.end(), Error::InvalidState);
        const auto& part = *found->second;
        selected.items.insert(part.items.begin(), part.items.end());
        selected.containers.insert(part.containers.begin(), part.containers.end());
        selected.placements.insert(part.placements.begin(), part.placements.end());
    }
    return selected;
}
World copy_roots(const World& world, const std::set<Id>& roots) {
    for (auto root : roots) {
        auto found = world.containers.find(root);
        require(found != world.containers.end() && !found->second.state.ownerItem, Error::InvalidState);
    }
    World selected;
    for (const auto& [id, container] : world.containers) {
        if (roots.contains(ancestry(world, id).back())) selected.containers.emplace(id, container);
    }
    for (const auto& [id, placement] : world.placements) {
        if (!selected.containers.contains(placement.container)) continue;
        selected.placements.emplace(id, placement);
        selected.items.emplace(id, world.items.at(id));
    }
    // Tombstones have no location; retain them in the committed world, not scratch.
    return selected;
}
}
