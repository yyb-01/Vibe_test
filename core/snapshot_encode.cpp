#include "snapshot.hpp"
#include "checkpoint_wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode_view(const RootSnapshot& view) {
    require(!view.roots.empty() && view.roots.size() <= 16, Error::InvalidState);
    std::size_t items = 0, containers = 0, places = 0;
    for (const auto& [root, part] : view.roots) {
        require(part && part->containers.contains(root) && !part->containers.at(root).state.ownerItem,
                Error::InvalidState);
        items += part->items.size(); containers += part->containers.size(); places += part->placements.size();
        require(items <= 65536 && containers <= 4096 && places <= 65536, Error::LimitExceeded);
    }
    auto size = 20 + 16 * view.roots.size() + 64 * items + 81 * containers + 48 * places;
    require(size <= snapshot_limit, Error::LimitExceeded);
    Writer w; w.bytes.reserve(size); w.put(0x31575641, 4); w.put(view.roots.size(), 4);
    for (const auto& [root, part] : view.roots) { (void)part; w.id(root); }
    w.put(items, 4); w.put(containers, 4); w.put(places, 4);
    for (const auto& [root, part] : view.roots) {
        (void)root;
        for (const auto& [id, item] : part->items) {
            require(id == item.id && !(item.flags & deleted), Error::InvalidState);
            auto publicItem = item;
            publicItem.birthEvent = publicItem.reservedBy = 0; publicItem.extraIndex = UINT32_MAX;
            checkpoint_wire::put(w, publicItem);
        }
    }
    for (const auto& [root, part] : view.roots) {
        (void)root;
        for (const auto& [id, container] : part->containers) { (void)id; checkpoint_wire::put(w, container); }
    }
    for (const auto& [root, part] : view.roots) {
        (void)root;
        for (const auto& [id, place] : part->placements) { (void)id; checkpoint_wire::put(w, place); }
    }
    return std::move(w.bytes);
}
}
