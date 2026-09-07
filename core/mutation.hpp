#pragma once
#include "inventory.hpp"

namespace astra {
inline void bump(std::uint64_t& revision) {
    require(revision < revision_limit, Error::LimitExceeded);
    ++revision;
}
inline Placement destination(const World& w, const MoveEntry& m, Id item) {
    Placement p;
    p.item = item; p.container = m.target; p.x = m.x; p.y = m.y;
    p.socketId = m.socketId; p.rotation = m.rotation; p.kind = w.containers.at(m.target).kind;
    return p;
}
void merge_stack(const Catalog&, World&, const MoveEntry&);
}
