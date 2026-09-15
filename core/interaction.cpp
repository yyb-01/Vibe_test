#include "interaction.hpp"
#include <cmath>

namespace astra {
std::set<Id> interaction_roots(const InteractionState& state, Id pawn) {
    require(state.pawn == pawn && state.alive && state.canInteract &&
            !state.roots.empty() && state.roots.size() <= 16, Error::NotAccessible);
    std::set<Id> roots;
    for (const auto& r : state.roots) {
        require(bool(r.root) && r.permitted && r.lineOfSight && std::isfinite(r.distanceM) &&
                r.distanceM >= 0 && r.distanceM <= 2.5 && roots.insert(r.root).second,
                Error::NotAccessible);
    }
    return roots;
}
}
