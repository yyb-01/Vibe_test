#include "grid.hpp"

namespace astra {
void validate_catalog(const Catalog&);
void validate(const Catalog& catalog, World& world) {
    validate_catalog(catalog);
    require(world.items.size() <= 65536 && world.containers.size() <= 4096, Error::LimitExceeded);
    std::map<Id, Grid> grids;
    std::map<Id, unsigned> counts;
    for (auto& [id, c] : world.containers) {
        auto& s = c.state;
        require(bool(id) && id == s.id && s.revision <= revision_limit, Error::InvalidState);
        require(c.kind == PlaceKind::Grid || c.kind == PlaceKind::Slot || c.kind == PlaceKind::World,
                Error::InvalidState);
        require(c.kind == PlaceKind::World || (s.width && s.width <= 32 && s.height && s.height <= 32),
                Error::InvalidState);
        auto chain = ancestry(world, id);
        s.depth = static_cast<std::uint8_t>(chain.size() - 1);
        s.subtreeMassG = s.usedVolumeMl = s.entryCount = 0;
        if (s.ownerItem) {
            const auto& item = world.items.at(s.ownerItem);
            require(catalog.contains(item.defId), Error::InvalidState);
            require(item.quantity == 1 && catalog.at(item.defId).containerDefId, Error::InvalidState);
        }
    }
    std::size_t live = 0;
    for (const auto& [id, item] : world.items) {
        require(bool(id) && item.id == id && catalog.contains(item.defId) && !world.containers.contains(id), Error::InvalidState);
        require(item.revision <= revision_limit && !item.reservedBy && !(item.flags & ~deleted), Error::InvalidState);
        if (item.flags & deleted) {
            require(!item.quantity && !world.placements.contains(id), Error::InvalidState);
            continue;
        }
        ++live;
        const auto& d = catalog.at(item.defId);
        require(item.quantity && item.quantity <= d.maxStack, Error::InvalidQuantity);
        require(world.placements.contains(id), Error::InvalidState);
        const auto& p = world.placements.at(id);
        auto chain = ancestry(world, p.container);
        auto& c = world.containers.at(p.container);
        require(p.item == id && (c.allowedClasses & (std::uint64_t{1} << d.classId)), Error::Incompatible);
        occupy(grids[p.container], c, d, p);
        require(++c.state.entryCount <= 256 && ++counts[chain.back()] <= 1024, Error::LimitExceeded);
        auto volume = std::uint64_t(d.outerVolumeMl) * item.quantity;
        require(volume <= c.state.capacityMl - c.state.usedVolumeMl, Error::CapacityExceeded);
        c.state.usedVolumeMl += static_cast<std::uint32_t>(volume);
        auto mass = std::uint64_t(d.massG) * item.quantity;
        for (auto ancestor : chain) {
            auto& parent = world.containers.at(ancestor);
            require(mass <= parent.maxMassG - parent.state.subtreeMassG, Error::CapacityExceeded);
            parent.state.subtreeMassG += mass;
        }
    }
    require(live == world.placements.size(), Error::InvalidState);
}
}
