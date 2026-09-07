#include "scenario.hpp"

void transactions() {
    Scenario s;
    auto before = s.inventory.snapshot();
    CHECK(before->containers.at(id(10)).state.subtreeMassG == 1100);
    CHECK(before->containers.at(id(10)).state.usedVolumeMl == 2250);
    auto r = s.request(Operation::Move, {move(*before, id(100), id(20))});
    auto result = s.inventory.apply(r, s.access);
    CHECK(result.applied() && result.sequence == 1);
    auto after = s.inventory.snapshot();
    CHECK(after->placements.at(id(100)).container == id(20));
    CHECK(before->placements.at(id(100)).container == id(10));
    CHECK(after->containers.at(id(20)).state.subtreeMassG == 3200);
    CHECK(s.inventory.apply(r, s.access).sequence == result.sequence);
    CHECK(s.inventory.snapshot() == after);
    r.moves[0].quantity = 1;
    CHECK(s.inventory.apply(r, s.access).code == Error::IdempotencyMismatch);
    CHECK(s.inventory.snapshot() == after);

    auto split = move(*after, id(100), id(20), 5);
    split.quantity = 7;
    auto splitRequest = s.request(Operation::Split, {split});
    auto splitResult = s.inventory.apply(splitRequest, s.access);
    CHECK(splitResult.applied() && bool(splitResult.created));
    auto splitState = s.inventory.snapshot();
    CHECK(splitState->items.at(splitResult.created).quantity == 7);
    CHECK(splitState->items.at(id(100)).quantity == 13);
    CHECK(s.inventory.apply(splitRequest, s.access).created == splitResult.created);
    auto mergeRequest = s.request(Operation::Merge, {move(*splitState, splitResult.created, id(20), 4)});
    CHECK(s.inventory.apply(mergeRequest, s.access).applied());
    auto merged = s.inventory.snapshot();
    CHECK(merged->items.at(id(100)).quantity == 20);
    CHECK(!merged->placements.contains(splitResult.created));
    CHECK(merged->items.at(splitResult.created).flags & deleted);
    CHECK(merged->items.at(splitResult.created).quantity == 0);
}

void swaps_and_world() {
    Scenario s;
    auto old = s.inventory.snapshot();
    auto swap = s.request(Operation::Swap, {move(*old, id(102), id(20), 0), move(*old, id(104), id(10), 2)});
    CHECK(s.inventory.apply(swap, s.access).applied());
    auto current = s.inventory.snapshot();
    CHECK(ancestry(*current, id(40)).back() == id(20));
    CHECK(current->containers.at(id(20)).state.subtreeMassG == 600);
    auto drop = s.request(Operation::Drop, {move(*current, id(100), id(30), 0)});
    CHECK(s.inventory.apply(drop, s.access).applied());
    auto pickup = s.request(Operation::Pickup, {move(*s.inventory.snapshot(), id(100), id(20), 5)});
    CHECK(s.inventory.apply(pickup, s.access).applied());
}
