#include "mutation.hpp"

namespace astra {
void mutate(const Catalog& catalog, World& w, const Request& r, Id created, std::uint64_t event) {
    std::set<Id> touched;
    for (const auto& m : r.moves) {
        for (auto endpoint : {m.source, m.target}) {
            auto chain = ancestry(w, endpoint);
            touched.insert(chain.begin(), chain.end());
        }
    }
    auto before = w.containers;
    for (const auto& m : r.moves) {
        auto& item = w.items.at(m.item);
        if (r.operation == Operation::Merge) { merge_stack(catalog, w, m); continue; }
        if (r.operation == Operation::Split) {
            require(m.quantity < item.quantity && item.extraIndex == UINT32_MAX, Error::InvalidQuantity);
            require(!w.items.contains(created) && !w.containers.contains(created), Error::InvalidState);
            auto split = item;
            split.id = created; split.quantity = m.quantity; split.revision = 1; split.birthEvent = event;
            bump(item.revision); item.quantity -= m.quantity;
            w.items.emplace(created, split);
            w.placements.emplace(created, destination(w, m, created));
        } else {
            require(m.quantity == item.quantity, Error::InvalidQuantity);
            bump(item.revision);
            w.placements.at(m.item) = destination(w, m, m.item);
        }
    }
    validate(catalog, w);
    for (auto& [id, c] : w.containers) {
        const auto& old = before.at(id).state;
        const auto& s = c.state;
        if (touched.contains(id) || old.subtreeMassG != s.subtreeMassG || old.usedVolumeMl != s.usedVolumeMl ||
            old.entryCount != s.entryCount || old.depth != s.depth) bump(c.state.revision);
    }
}
}
