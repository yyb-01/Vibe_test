#pragma once
#include "delta_wire.hpp"

namespace astra::checkpoint_wire {
inline void put_game(Writer& w, const Container& c) {
    put(w, c); w.put(c.gameplay.size(), 4);
    w.bytes.insert(w.bytes.end(), c.gameplay.begin(), c.gameplay.end());
}
inline Container game_container(Reader& r) {
    auto c = container(r); auto n = r.get(4);
    require(n <= 16 * 1024 * 1024 && n <= r.bytes.size() - r.position, Error::InvalidState);
    c.gameplay.assign(r.bytes.begin() + r.position, r.bytes.begin() + r.position + n);
    r.position += n; return c;
}
}
namespace astra::delta_wire {
template<> inline void put(Writer& w, const std::map<Id, RowChange<Container>>& rows, std::size_t limit) {
    require(rows.size() <= limit, Error::LimitExceeded); w.put(rows.size(), 4);
    for (const auto& [id, c] : rows) {
        require(c.before || c.after, Error::InvalidState);
        w.id(id); w.put((c.before ? 1 : 0) | (c.after ? 2 : 0), 1);
        if (c.before) checkpoint_wire::put_game(w, *c.before);
        if (c.after) checkpoint_wire::put_game(w, *c.after);
    }
}
}
