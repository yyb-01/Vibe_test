#include "snapshot.hpp"
#include "checkpoint_wire.hpp"
#include "inventory.hpp"

namespace astra {
World decode_view(const std::vector<std::uint8_t>& bytes, const Catalog& catalog) {
    require(bytes.size() >= 36 && bytes.size() <= snapshot_limit, Error::InvalidRequest);
    Reader r{bytes}; require(r.get(4) == 0x31575641, Error::Incompatible);
    auto rootCount = r.get(4); require(rootCount && rootCount <= 16, Error::InvalidRequest);
    std::set<Id> roots;
    for (std::size_t n = 0; n < rootCount; ++n) {
        auto root = r.id(); require(bool(root) && roots.insert(root).second, Error::InvalidRequest);
    }
    auto items = r.get(4), containers = r.get(4), places = r.get(4);
    require(items <= 65536 && containers <= 4096 && places == items &&
            bytes.size() == r.position + 64 * items + 81 * containers + 48 * places, Error::InvalidRequest);
    World world;
    for (std::size_t n = 0; n < items; ++n) {
        auto item = checkpoint_wire::item(r);
        require(!item.flags && !item.birthEvent && !item.reservedBy && item.extraIndex == UINT32_MAX &&
                world.items.emplace(item.id, item).second, Error::InvalidRequest);
    }
    for (std::size_t n = 0; n < containers; ++n) {
        auto c = checkpoint_wire::container(r);
        require(world.containers.emplace(c.state.id, c).second, Error::InvalidRequest);
    }
    for (std::size_t n = 0; n < places; ++n) {
        auto p = checkpoint_wire::placement(r);
        require(world.placements.emplace(p.item, p).second, Error::InvalidRequest);
    }
    verify_world(catalog, world);
    for (const auto& [id, c] : world.containers) {
        if (!c.state.ownerItem) require(roots.erase(id) == 1, Error::InvalidRequest);
    }
    require(roots.empty(), Error::InvalidRequest);
    return world;
}
}
