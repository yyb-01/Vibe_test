#include "inventory.hpp"

namespace astra {
void check_request(const World& w, const Request& r, const Access& access) {
    require(bool(r.id) && r.actionSeq && r.actionSeq <= revision_limit, Error::InvalidRequest);
    require(r.interactionLease && r.interactionLease == access.interactionLease, Error::NotAccessible);
    require(r.operation != Operation::Swap || r.moves.size() == 2, Error::InvalidRequest);
    require((r.operation != Operation::Split && r.operation != Operation::Merge) || r.moves.size() == 1,
            Error::InvalidRequest);
    std::set<Id> seen;
    for (const auto& m : r.moves) {
        require(seen.insert(m.item).second && m.rotation <= 1, Error::InvalidRequest);
        require(w.items.contains(m.item) && w.placements.contains(m.item), Error::NotAccessible);
        require(w.containers.contains(m.source) && w.containers.contains(m.target), Error::NotAccessible);
        require(w.placements.at(m.item).container == m.source, Error::RevisionConflict);
        for (auto c : {m.source, m.target}) {
            require(access.roots.contains(ancestry(w, c).back()), Error::NotAccessible);
        }
        const auto& item = w.items.at(m.item);
        require(!(item.flags & deleted) && item.revision == m.itemRev, Error::RevisionConflict);
        require(w.containers.at(m.source).state.revision == m.sourceRev &&
                w.containers.at(m.target).state.revision == m.targetRev, Error::RevisionConflict);
        require(m.quantity && m.quantity <= item.quantity, Error::InvalidQuantity);
        if (r.operation == Operation::Drop)
            require(w.containers.at(m.target).kind == PlaceKind::World, Error::InvalidPlacement);
        if (r.operation == Operation::Pickup)
            require(w.containers.at(m.source).kind == PlaceKind::World, Error::InvalidPlacement);
    }
    if (r.operation == Operation::Swap) {
        require(r.moves[0].source == r.moves[1].target && r.moves[1].source == r.moves[0].target,
                Error::InvalidRequest);
    }
}
}
