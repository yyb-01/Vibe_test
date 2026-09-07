#include "scenario.hpp"
#include "allocation_probe.hpp"
#include <atomic>
#include <barrier>
#include <new>
#include <thread>

namespace {
Result commit_without_allocation(Inventory& inventory, const std::shared_ptr<const WriteSet>& changes) {
    Result result;
    std::size_t calls;
    {
        allocation_probe::Scope probe(0);
        result = inventory.commit(changes);
        calls = probe.count();
    }
    CHECK(calls == 0);
    return result;
}
}

void root_snapshot_sharing() {
    Scenario s;
    auto before = s.inventory.snapshot_roots({id(10), id(20), id(30)});
    auto flat = s.inventory.snapshot();
    CHECK(before.sequence == 0 && before.roots.size() == 3);
    CHECK(before.roots.at(id(10))->containers.contains(id(40)));
    CHECK(before.roots.at(id(10))->items.size() == 4);
    CHECK(before.roots.at(id(20))->items.size() == 1);
    CHECK(before.roots.at(id(30))->items.empty());
    CHECK(s.inventory.snapshot_roots({}).roots.empty());
    rejects([&] { (void)s.inventory.snapshot_roots({id(40)}); }, Error::InvalidState);
    rejects([&] { (void)s.inventory.snapshot_roots({id(999)}); }, Error::InvalidState);
    auto request = s.request(Operation::Move, {move(*flat, id(100), id(10), 6)});
    auto pending = s.inventory.prepare(request, s.access);
    CHECK(pending.changes && pending.changes->outcome.applied());
    CHECK(s.inventory.snapshot_roots({id(10)}).roots.at(id(10)) == before.roots.at(id(10)));
    CHECK(s.inventory.commit(pending.changes).applied());
    auto after = s.inventory.snapshot_roots({id(10), id(20), id(30)});
    CHECK(after.sequence == 1);
    CHECK(after.roots.at(id(10)) != before.roots.at(id(10)));
    CHECK(after.roots.at(id(20)) == before.roots.at(id(20)));
    CHECK(after.roots.at(id(30)) == before.roots.at(id(30)));
    CHECK(after.roots.at(id(10))->placements.at(id(100)).x == 6);
    CHECK(before.roots.at(id(10))->placements.at(id(100)).x == 0);
    CHECK(flat->placements.at(id(100)).x == 0);
    CHECK(copy_roots(after.roots, {id(10), id(20), id(30)}) == *s.inventory.snapshot());

    auto state = s.inventory.snapshot();
    auto swap = s.request(Operation::Swap, {
        move(*state, id(102), id(20), 0), move(*state, id(104), id(10), 2)});
    CHECK(s.inventory.apply(swap, s.access).applied());
    auto swapped = s.inventory.snapshot_roots({id(10), id(20), id(30)});
    CHECK(!swapped.roots.at(id(10))->containers.contains(id(40)));
    CHECK(!swapped.roots.at(id(10))->items.contains(id(103)));
    CHECK(swapped.roots.at(id(20))->containers.contains(id(40)));
    CHECK(swapped.roots.at(id(20))->items.contains(id(102)));
    CHECK(swapped.roots.at(id(20))->items.contains(id(103)));
    CHECK(after.roots.at(id(10))->containers.contains(id(40)));
    CHECK(swapped.roots.at(id(30)) == before.roots.at(id(30)));
    CHECK(copy_roots(swapped.roots, {id(10), id(20), id(30)}) == *s.inventory.snapshot());
}

void allocation_free_publication() {
    Scenario s;
    auto original = s.inventory.snapshot();
    auto oldRoots = s.inventory.snapshot_roots({id(10), id(20), id(30)});
    auto part = move(*original, id(100), id(20)); part.quantity = 7;
    auto split = s.inventory.prepare(s.request(Operation::Split, {part}), s.access);
    CHECK(split.changes && split.changes->outcome.applied());
    auto result = commit_without_allocation(s.inventory, split.changes);
    CHECK(result.applied() && result.sequence == 1);
    CHECK(commit_without_allocation(s.inventory, split.changes).sequence == 1);
    CHECK(original->items.at(id(100)).quantity == 20);
    CHECK(oldRoots.roots.at(id(10))->items.at(id(100)).quantity == 20);

    auto state = s.inventory.snapshot();
    auto merge = s.inventory.prepare(s.request(Operation::Merge, {move(*state, result.created, id(10), 0)}), s.access);
    CHECK(commit_without_allocation(s.inventory, merge.changes).applied());
    auto merged = s.inventory.snapshot_roots({id(10), id(20)});
    CHECK(!merged.roots.at(id(20))->items.contains(result.created));
    CHECK(s.inventory.snapshot()->items.at(result.created).flags & deleted);
    CHECK(!s.inventory.snapshot()->placements.contains(result.created));

    state = s.inventory.snapshot();
    auto swap = s.inventory.prepare(s.request(Operation::Swap, {
        move(*state, id(102), id(20), 0), move(*state, id(104), id(10), 2)}), s.access);
    CHECK(commit_without_allocation(s.inventory, swap.changes).applied());
    auto current = s.inventory.snapshot_roots({id(10), id(20), id(30)});
    state = s.inventory.snapshot();
    auto invalid = s.inventory.prepare(s.request(Operation::Move, {
        move(*state, id(100), id(20), UINT16_MAX)}), s.access);
    CHECK(commit_without_allocation(s.inventory, invalid.changes).code == Error::InvalidPlacement);
    CHECK(s.inventory.snapshot_roots({id(10), id(20), id(30)}).roots == current.roots);
    CHECK(s.inventory.snapshot() == state);

    auto cancel = s.inventory.prepare(s.request(Operation::Move, {move(*state, id(100), id(10), 5)}), s.access);
    CHECK(cancel.changes && cancel.changes->outcome.applied());
    bool aborted;
    { allocation_probe::Scope probe(0); aborted = s.inventory.abort(cancel.changes); }
    CHECK(aborted);
    CHECK(commit_without_allocation(s.inventory, cancel.changes).code == Error::InvalidRequest);
    CHECK(s.inventory.snapshot_roots({id(10), id(20), id(30)}).roots == current.roots);
    CHECK(s.inventory.snapshot() == state);
}

void prepare_allocation_rollback() {
    bool reachedSuccess = false;
    unsigned failures = 0;
    for (std::size_t failAfter = 0; failAfter < 1024; ++failAfter) {
        Scenario s;
        auto flat = s.inventory.snapshot();
        auto roots = s.inventory.snapshot_roots({id(10), id(20), id(30)});
        auto part = move(*flat, id(100), id(20)); part.quantity = 7;
        auto request = s.request(Operation::Split, {part});
        Preparation prepared;
        bool failed = false;
        try {
            allocation_probe::Scope probe(failAfter);
            prepared = s.inventory.prepare(request, s.access);
        } catch (const std::bad_alloc&) { failed = true; }
        CHECK(s.inventory.snapshot() == flat);
        CHECK(s.inventory.snapshot_roots({id(10), id(20), id(30)}).roots == roots.roots);
        if (failed) {
            ++failures;
            // Every failed allocation leaves IDs, order, and reservations untouched.
            prepared = s.inventory.prepare(request, s.access);
            CHECK(prepared.changes && prepared.changes->outcome.applied());
            CHECK(prepared.changes->event == 1 && prepared.changes->outcome.created == id(105));
            CHECK(commit_without_allocation(s.inventory, prepared.changes).sequence == 1);
            CHECK(s.inventory.snapshot()->items.at(id(100)).quantity == 13);
        } else {
            CHECK(prepared.changes && prepared.changes->outcome.applied());
            CHECK(s.inventory.abort(prepared.changes));
            reachedSuccess = true;
            break;
        }
    }
    CHECK(reachedSuccess && failures > 0);
}

void concurrent_root_snapshots() {
    Scenario s;
    auto old = s.inventory.snapshot_roots({id(10), id(20)});
    std::barrier start(4);
    std::atomic<bool> failed{};
    std::vector<std::jthread> threads;
    for (unsigned i = 0; i < 3; ++i) {
        threads.emplace_back([&] {
            start.arrive_and_wait();
            try {
                for (unsigned j = 0; j < 250; ++j) {
                    auto roots = s.inventory.snapshot_roots({id(10), id(20)});
                    auto combined = copy_roots(roots.roots, {id(10), id(20)});
                    auto checked = combined;
                    validate(catalog(), checked);
                    CHECK(checked == combined);
                    CHECK(combined.items.size() == 5 && combined.placements.size() == 5);
                    CHECK(combined.containers.at(id(10)).state.subtreeMassG +
                          combined.containers.at(id(20)).state.subtreeMassG == 4100);
                    CHECK(roots.roots.at(id(10))->items.contains(id(102)) !=
                          roots.roots.at(id(20))->items.contains(id(102)));
                    CHECK(old.roots.at(id(10))->placements.at(id(102)).container == id(10));
                }
            } catch (...) { failed = true; }
        });
    }
    start.arrive_and_wait();
    for (unsigned i = 0; i < 200; ++i) {
        auto roots = s.inventory.snapshot_roots({id(10), id(20)});
        auto world = copy_roots(roots.roots, {id(10), id(20)});
        auto bag = world.placements.at(id(102)), rifle = world.placements.at(id(104));
        auto request = s.request(Operation::Swap, {
            move(world, id(102), rifle.container, rifle.x, rifle.y),
            move(world, id(104), bag.container, bag.x, bag.y)});
        CHECK(s.inventory.apply(request, s.access).applied());
    }
    threads.clear();
    CHECK(!failed && s.inventory.snapshot_roots({id(10), id(20)}).sequence == 200);
    CHECK(old.roots.at(id(10))->items.at(id(102)).revision == 1);
}
