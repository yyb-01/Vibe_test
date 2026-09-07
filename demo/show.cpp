#include "console.hpp"
#include <iostream>

void show(const World& w) {
    for (const auto& [id, c] : w.containers) {
        const auto& s = c.state;
        std::cout << "Container " << id.lo << " rev=" << s.revision
                  << " mass=" << s.subtreeMassG << "g volume=" << s.usedVolumeMl << '/' << s.capacityMl
                  << "mL ownerItem=" << s.ownerItem.lo << '\n';
        for (const auto& [itemId, p] : w.placements) {
            if (p.container != id) continue;
            const auto& item = w.items.at(itemId);
            std::cout << "  item " << itemId.lo << " def=" << item.defId << " qty=" << item.quantity
                      << " grid=" << p.x << ',' << p.y << " rev=" << item.revision << '\n';
        }
    }
}
