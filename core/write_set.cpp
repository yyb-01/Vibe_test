#include "write_set.hpp"

namespace astra {
namespace {
template<class T>
void diff(const std::map<Id, T>& before, const std::map<Id, T>& after,
          std::map<Id, RowChange<T>>& changes) {
    auto old = before.begin(), next = after.begin();
    while (old != before.end() || next != after.end()) {
        if (next == after.end() || (old != before.end() && old->first < next->first)) {
            changes.emplace(old->first, RowChange<T>{old->second, std::nullopt});
            ++old;
        } else if (old == before.end() || next->first < old->first) {
            changes.emplace(next->first, RowChange<T>{std::nullopt, next->second});
            ++next;
        } else {
            if (old->second != next->second)
                changes.emplace(old->first, RowChange<T>{old->second, next->second});
            ++old; ++next;
        }
    }
}
}
void describe_changes(const World& before, const World& after, WriteSet& changes) {
    changes.items.clear(); changes.containers.clear(); changes.placements.clear();
    diff(before.items, after.items, changes.items);
    diff(before.containers, after.containers, changes.containers);
    diff(before.placements, after.placements, changes.placements);
}
}
