#pragma once
#include "transaction.hpp"
#include "world.hpp"
#include <memory>
#include <optional>

namespace astra {
// Missing before/after means insert/delete. Compare fields, never POD padding.
template<class T> struct RowChange {
    std::optional<T> before, after;
};
struct WriteSet {
    Id account, requestId;
    std::uint64_t epoch{}, actionSeq{};
    std::uint64_t event{}; // Epoch-local preparation ID; burned on abort, zero for rejection.
    std::vector<std::uint8_t> payload;
    std::vector<Id> roots; // Stable ID order; affected roots before mutation.
    Result outcome; // Proposed code/created ID. sequence stays zero until commit.
    std::map<Id, RowChange<ItemState>> items;
    std::map<Id, RowChange<Container>> containers;
    std::map<Id, RowChange<Placement>> placements;
};
struct Preparation {
    Result result;
    // Non-null only for an owned pending transaction (including a rejection).
    // result.code remains Pending until Inventory::commit resolves it.
    std::shared_ptr<const WriteSet> changes;
};
void describe_changes(const World& before, const World& after, WriteSet&);
}
