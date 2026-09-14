#pragma once
#include "checkpoint_wire.hpp"
#include "checkpoint_delta.hpp"

namespace astra::delta_wire {
template<class T> void put(Writer& w, const std::map<Id, RowChange<T>>& rows, std::size_t limit) {
    require(rows.size() <= limit, Error::LimitExceeded);
    w.put(rows.size(), 4);
    for (const auto& [id, change] : rows) {
        require(change.before || change.after, Error::InvalidState);
        w.id(id); w.put((change.before ? 1 : 0) | (change.after ? 2 : 0), 1);
        if (change.before) checkpoint_wire::put(w, *change.before);
        if (change.after) checkpoint_wire::put(w, *change.after);
    }
}
template<class T, class Read> void get(Reader& r, std::map<Id, RowChange<T>>& rows, std::size_t limit, Read read) {
    auto count = r.get(4); require(count <= limit, Error::LimitExceeded);
    for (; count; --count) {
        auto id = r.id(); auto flags = r.get(1);
        require(flags >= 1 && flags <= 3, Error::InvalidState);
        RowChange<T> change;
        if (flags & 1) change.before = read(r);
        if (flags & 2) change.after = read(r);
        require(rows.emplace(id, std::move(change)).second, Error::InvalidState);
    }
}
}
