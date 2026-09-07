#include "scenario.hpp"
#include <barrier>
#include <thread>

namespace {
World islands(unsigned count) {
    World world;
    for (unsigned i = 0; i < count; ++i) {
        world.containers.emplace(id(10 + i), container(10 + i));
        add_item(world, 1000 + i, 1, 20, 10 + i);
    }
    return world;
}
Access access_for(unsigned account, unsigned roots) {
    Access access{{77, account + 1}, 1, 99, {}};
    for (unsigned i = 0; i < roots; ++i) access.roots.insert(id(10 + i));
    return access;
}
Request relocate(const World& world, unsigned index, std::uint64_t action = 1) {
    return {{88 + index, action}, action, Operation::Move,
            {move(world, id(1000 + index), id(10 + index), 1)}, 0, 99};
}
void valid_world(const World& world) {
    auto checked = world;
    validate(catalog(), checked);
    CHECK(checked == world);
}
}

void disjoint_commit_order() {
    Inventory inventory(catalog(), islands(3), 1, 1);
    auto before = inventory.snapshot();
    auto a = relocate(*before, 0), b = relocate(*before, 1);
    a.operation = b.operation = Operation::Split;
    a.moves[0].quantity = b.moves[0].quantity = 7;
    auto first = inventory.prepare(a, access_for(0, 3));
    auto second = inventory.prepare(b, access_for(1, 3));
    CHECK(first.changes && second.changes);
    CHECK(inventory.snapshot() == before);
    CHECK(first.changes->event == 1 && second.changes->event == 2);
    CHECK(first.changes->outcome.created != second.changes->outcome.created);
    CHECK(first.changes->outcome.sequence == 0 && second.changes->outcome.sequence == 0);
    CHECK(first.changes->containers.size() == 1 && second.changes->containers.size() == 1);

    // A third root can use the synchronous API while both splits wait.
    auto third = inventory.apply(relocate(*before, 2), access_for(2, 3));
    CHECK(third.applied() && third.sequence == 1);
    auto middle = inventory.snapshot();
    CHECK(middle->placements.at(id(1002)).x == 1);
    CHECK(middle->items.at(id(1000)).quantity == 20);
    CHECK(inventory.apply(a, access_for(0, 3)).code == Error::Pending);
    CHECK(inventory.snapshot() == middle);

    auto secondResult = inventory.commit(second.changes);
    CHECK(secondResult.applied() && secondResult.sequence == 2);
    auto firstResult = inventory.commit(first.changes);
    CHECK(firstResult.applied() && firstResult.sequence == 3);
    auto after = inventory.snapshot();
    CHECK(after->items.at(id(1000)).quantity == 13 && after->items.at(id(1001)).quantity == 13);
    CHECK(after->items.at(firstResult.created).birthEvent == 1);
    CHECK(after->items.at(secondResult.created).birthEvent == 2);
    CHECK(after->placements.at(id(1002)).x == 1);
    CHECK(before->placements.at(id(1002)).x == 0);
    CHECK(middle->items.at(id(1001)).quantity == 20);
    CHECK(inventory.apply(a, access_for(0, 3)).sequence == 3);
    CHECK(inventory.commit(second.changes).sequence == 2);
    CHECK(inventory.snapshot() == after);
    valid_world(*after);
}

void root_reservations() {
    Inventory inventory(catalog(), islands(3), 1, 1);
    auto before = inventory.snapshot();
    auto locked = inventory.prepare(relocate(*before, 1), access_for(1, 3));
    CHECK(locked.changes);
    auto crosses = relocate(*before, 0);
    crosses.moves = {move(*before, id(1000), id(11), 2)};
    CHECK(inventory.prepare(crosses, access_for(0, 3)).result.code == Error::Busy);
    // Failed multi-root acquisition must not leave its free root reserved.
    auto freeRoot = inventory.prepare(relocate(*before, 0), access_for(3, 3));
    CHECK(freeRoot.changes && freeRoot.changes->outcome.applied());
    // An account remains ordered even when its next request uses another root.
    auto nextAccountAction = relocate(*before, 2, 2);
    CHECK(inventory.prepare(nextAccountAction, access_for(1, 3)).result.code == Error::Busy);
    CHECK(inventory.abort(locked.changes));
    auto rootOne = inventory.prepare(relocate(*before, 1), access_for(4, 3));
    CHECK(rootOne.changes);
    CHECK(inventory.commit(freeRoot.changes).applied());
    CHECK(inventory.commit(rootOne.changes).applied());

    // A rejected scratch simulation does not reserve rows or roots.
    auto current = inventory.snapshot();
    auto bad = relocate(*current, 0); bad.moves[0].x = UINT16_MAX;
    auto rejected = inventory.prepare(bad, access_for(5, 3));
    CHECK(rejected.changes && rejected.changes->outcome.code == Error::InvalidPlacement);
    CHECK(rejected.changes->roots.empty() && rejected.changes->event == 0);
    auto good = relocate(*current, 0); good.moves[0].x = 2;
    CHECK(inventory.apply(good, access_for(6, 3)).sequence == 3);
    auto rejection = inventory.commit(rejected.changes);
    CHECK(rejection.code == Error::InvalidPlacement && rejection.sequence == 3);
    CHECK(inventory.commit(rejected.changes).sequence == 3);
    valid_world(*inventory.snapshot());

    // Nested contents reserve the top-level root, including both ends of a move.
    Scenario nested;
    auto old = nested.inventory.snapshot();
    auto bag = nested.request(Operation::Move, {move(*old, id(102), id(20), 4)});
    auto pendingBag = nested.inventory.prepare(bag, nested.access);
    CHECK(pendingBag.changes && pendingBag.changes->outcome.applied());
    auto other = nested.access; other.account = {77, 2};
    Request pouch{{99, 1}, 1, Operation::Move, {move(*old, id(103), id(30), 0)}, 0, 99};
    CHECK(nested.inventory.prepare(pouch, other).result.code == Error::Busy);
    CHECK(nested.inventory.abort(pendingBag.changes));
    auto pendingPouch = nested.inventory.prepare(pouch, other);
    CHECK(pendingPouch.changes && pendingPouch.changes->outcome.applied());
    CHECK((pendingPouch.changes->roots == std::vector<Id>{id(10), id(30)}));
    auto rifle = nested.request(Operation::Move, {move(*old, id(104), id(20), 3)});
    rifle.actionSeq = 1; // The aborted bag request consumed no account sequence.
    CHECK(nested.inventory.apply(rifle, nested.access).applied());
    CHECK(nested.inventory.commit(pendingPouch.changes).applied());
    CHECK(nested.inventory.snapshot()->containers.at(id(40)).state.subtreeMassG == 0);
    CHECK(nested.inventory.snapshot()->placements.at(id(104)).x == 3);
    valid_world(*nested.inventory.snapshot());
}

void concurrent_disjoint_roots() {
    Inventory inventory(catalog(), islands(20), 1, 1);
    auto before = inventory.snapshot();
    std::barrier start(20);
    std::vector<Preparation> prepared(20);
    std::vector<Result> committed(20);
    std::vector<std::jthread> threads;
    for (unsigned i = 0; i < 20; ++i) {
        threads.emplace_back([&, i] {
            start.arrive_and_wait();
            prepared[i] = inventory.prepare(relocate(*before, i), access_for(i, 20));
        });
    }
    threads.clear();
    CHECK(inventory.snapshot() == before);
    std::set<std::uint64_t> events;
    for (const auto& preparation : prepared) {
        CHECK(preparation.changes && preparation.changes->outcome.applied());
        CHECK(preparation.changes->roots.size() == 1 && preparation.changes->items.size() == 1);
        CHECK(events.insert(preparation.changes->event).second);
    }
    for (unsigned i = 0; i < 20; ++i) {
        threads.emplace_back([&, i] {
            start.arrive_and_wait();
            committed[i] = inventory.commit(prepared[i].changes);
        });
    }
    threads.clear();
    std::set<std::uint64_t> sequences;
    for (unsigned i = 0; i < 20; ++i) {
        CHECK(committed[i].applied() && sequences.insert(committed[i].sequence).second);
        CHECK(inventory.snapshot()->placements.at(id(1000 + i)).x == 1);
        CHECK(inventory.snapshot()->items.at(id(1000 + i)).revision == 2);
        CHECK(before->placements.at(id(1000 + i)).x == 0);
    }
    CHECK(*sequences.begin() == 1 && *sequences.rbegin() == 20);
    valid_world(*inventory.snapshot());
}

void pending_account_limit() {
    Inventory inventory(catalog(), islands(65), 1, 1);
    auto before = inventory.snapshot();
    std::vector<Preparation> prepared;
    for (unsigned i = 0; i < 64; ++i) {
        prepared.push_back(inventory.prepare(relocate(*before, i), access_for(i, 65)));
        CHECK(prepared.back().changes && prepared.back().changes->outcome.applied());
    }
    auto extra = relocate(*before, 64);
    CHECK(inventory.prepare(extra, access_for(64, 65)).result.code == Error::Busy);
    CHECK(inventory.abort(prepared[0].changes));
    auto replacement = inventory.prepare(extra, access_for(64, 65));
    CHECK(replacement.changes && replacement.changes->outcome.applied());
    CHECK(inventory.commit(replacement.changes).applied());
    // One committed account plus 63 pending new accounts still fills the limit.
    CHECK(inventory.prepare(relocate(*before, 0), access_for(0, 65)).result.code == Error::Busy);
    for (unsigned i = 1; i < 64; ++i) CHECK(inventory.commit(prepared[i].changes).applied());
    CHECK(inventory.prepare(relocate(*before, 0), access_for(0, 65)).result.code == Error::LimitExceeded);
    auto repeat = relocate(*inventory.snapshot(), 64, 2); repeat.moves[0].x = 2;
    CHECK(inventory.apply(repeat, access_for(64, 65)).applied());
    valid_world(*inventory.snapshot());
}

void partial_copy_item_limit() {
    auto world = islands(2);
    for (unsigned i = 0; i < 65533; ++i) {
        ItemState tombstone;
        tombstone.id = id(2000 + i); tombstone.defId = 1;
        tombstone.quantity = 0; tombstone.flags = deleted;
        world.items.emplace(tombstone.id, tombstone);
    }
    Inventory inventory(catalog(), world, 1, 1);
    auto before = inventory.snapshot();
    auto scratch = copy_roots(*before, {id(10)});
    CHECK(scratch.items.size() == 1 && scratch.containers.size() == 1 && scratch.placements.size() == 1);
    CHECK(scratch.items.contains(id(1000)) && !scratch.items.contains(id(1001)));
    CHECK(!scratch.items.contains(id(2000)));
    CHECK(copy_roots(*before, {}).items.empty());
    rejects([&] { (void)copy_roots(*before, {id(999)}); }, Error::InvalidState);

    auto a = relocate(*before, 0), b = relocate(*before, 1);
    a.operation = b.operation = Operation::Split;
    a.moves[0].quantity = b.moves[0].quantity = 1;
    auto first = inventory.prepare(a, access_for(0, 2));
    CHECK(first.changes && first.changes->outcome.applied());
    // Scratch is small, but global item capacity includes tombstones AND pending inserts.
    CHECK(inventory.prepare(b, access_for(1, 2)).result.code == Error::Busy);
    CHECK(inventory.abort(first.changes));
    auto second = inventory.prepare(b, access_for(1, 2));
    CHECK(second.changes && second.changes->outcome.applied());
    CHECK(inventory.commit(second.changes).applied());
    CHECK(inventory.snapshot()->items.size() == 65536);
    CHECK(inventory.snapshot()->items.at(id(2000)).flags & deleted);
    auto full = inventory.prepare(a, access_for(0, 2));
    CHECK(full.changes && full.changes->outcome.code == Error::LimitExceeded);
    CHECK(inventory.commit(full.changes).code == Error::LimitExceeded);
    CHECK(inventory.snapshot()->items.size() == 65536);
    CHECK(before->items.size() == 65535 && before->items.at(id(1001)).quantity == 20);
    valid_world(*inventory.snapshot());
}
