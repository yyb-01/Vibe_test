#include "scenario.hpp"

void rejections() {
    Scenario s;
    auto old = s.inventory.snapshot();
    auto invalid = move(*old, id(101), id(20), UINT16_MAX);
    auto batch = s.request(Operation::Move, {move(*old, id(100), id(20)), invalid});
    CHECK(s.inventory.apply(batch, s.access).code == Error::InvalidPlacement);
    CHECK(s.inventory.snapshot() == old);
    CHECK(s.inventory.apply(batch, s.access).code == Error::InvalidPlacement);
    auto cycle = s.request(Operation::Move, {move(*old, id(102), id(40), 2)});
    CHECK(s.inventory.apply(cycle, s.access).code == Error::CycleDetected);
    CHECK(s.inventory.snapshot() == old);
    auto denied = s.request(Operation::Move, {move(*old, id(103), id(20))});
    auto access = s.access; access.roots = {id(40), id(20)};
    CHECK(s.inventory.apply(denied, access).code == Error::NotAccessible);
    auto stale = move(*old, id(100), id(20)); stale.itemRev = 999;
    CHECK(s.inventory.apply(s.request(Operation::Move, {stale}), s.access).code == Error::RevisionConflict);
    auto duplicate = move(*old, id(100), id(20));
    CHECK(s.inventory.apply(s.request(Operation::Move, {duplicate, duplicate}), s.access).code == Error::InvalidRequest);
    auto epoch = s.access; epoch.epoch = 2;
    CHECK(s.inventory.apply(batch, epoch).code == Error::EpochMismatch);
    auto quantity = move(*old, id(100), id(20)); quantity.quantity = UINT32_MAX;
    CHECK(s.inventory.apply(s.request(Operation::Move, {quantity}), s.access).code == Error::InvalidQuantity);
    CHECK(s.inventory.snapshot() == old);
}

void capacity_and_conditions() {
    auto state = seed(); state.containers.at(id(20)).maxMassG = 3000;
    Inventory inventory(catalog(), state, 1, 1);
    Scenario s;
    auto request = s.request(Operation::Move, {move(*inventory.snapshot(), id(100), id(20))});
    CHECK(inventory.apply(request, s.access).code == Error::CapacityExceeded);
    CHECK(inventory.snapshot()->placements.at(id(100)).container == id(10));
    state = seed(); state.items.at(id(101)).contamination = 1;
    Inventory dirty(catalog(), state, 1, 1);
    request.operation = Operation::Merge; request.moves = {move(*dirty.snapshot(), id(100), id(10), 1)};
    CHECK(dirty.apply(request, s.access).code == Error::Incompatible);

    Scenario local;
    Inventory remote(catalog(), seed(), 1, 7);
    auto part = move(*remote.snapshot(), id(100), id(20)); part.quantity = 1;
    auto split = local.request(Operation::Split, {part});
    auto a = local.inventory.apply(split, local.access);
    auto b = remote.apply(split, local.access);
    CHECK(a.applied() && b.applied());
    CHECK(a.created.hi == 1 && b.created.hi == 7 && a.created != b.created);
}
