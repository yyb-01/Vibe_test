#include "scenario.hpp"
#include <atomic>
#include <barrier>
#include <thread>

namespace {
template<class T>
void replay_rows(std::map<Id, T>& rows, const std::map<Id, RowChange<T>>& changes) {
    for (const auto& [key, change] : changes) {
        CHECK(change.before || change.after);
        if (change.before) {
            CHECK(rows.contains(key));
            CHECK(rows.at(key) == *change.before);
        } else CHECK(!rows.contains(key));
        if (change.after) rows.insert_or_assign(key, *change.after);
        else rows.erase(key);
    }
}
World replay(World before, const WriteSet& changes) {
    replay_rows(before.items, changes.items);
    replay_rows(before.containers, changes.containers);
    replay_rows(before.placements, changes.placements);
    return before;
}
}

void prepared_lifecycle() {
    Scenario s;
    auto before = s.inventory.snapshot();
    auto request = s.request(Operation::Move, {move(*before, id(100), id(20))});
    auto prepared = s.inventory.prepare(request, s.access);
    CHECK(prepared.result.code == Error::Pending && !prepared.result.applied());
    CHECK(s.inventory.snapshot() == before);
    const auto& changes = *prepared.changes;
    CHECK(changes.account == s.access.account && changes.requestId == request.id);
    CHECK(changes.epoch == 1 && changes.actionSeq == 1 && changes.payload == encode(request));
    CHECK(changes.outcome.applied() && changes.outcome.sequence == 0 && changes.event == 1);
    CHECK((changes.roots == std::vector<Id>{id(10), id(20)}));
    CHECK(changes.items.size() == 1 && changes.containers.size() == 2 && changes.placements.size() == 1);
    CHECK(changes.items.at(id(100)).before->revision == 1);
    CHECK(changes.items.at(id(100)).after->revision == 2);
    CHECK(changes.containers.at(id(10)).before->state.subtreeMassG == 1100);
    CHECK(changes.containers.at(id(10)).after->state.subtreeMassG == 900);
    CHECK(s.inventory.prepare(request, s.access).changes == prepared.changes);
    CHECK(s.inventory.apply(request, s.access).code == Error::Pending);
    CHECK(s.inventory.snapshot() == before);
    auto changed = request; changed.moves[0].x = 5;
    CHECK(s.inventory.prepare(changed, s.access).result.code == Error::IdempotencyMismatch);
    auto staleEpoch = s.access; staleEpoch.epoch = 2;
    CHECK(s.inventory.prepare(request, staleEpoch).result.code == Error::EpochMismatch);

    auto contender = request; contender.id = {88, 2};
    auto other = s.access; other.account = {77, 2};
    CHECK(s.inventory.apply(contender, other).code == Error::Busy);
    auto result = s.inventory.commit(prepared.changes);
    CHECK(result.applied() && result.sequence == 1);
    auto after = s.inventory.snapshot();
    CHECK(*after == replay(*before, changes));
    CHECK(before->placements.at(id(100)).container == id(10));
    CHECK(s.inventory.commit(prepared.changes).sequence == 1);
    CHECK(s.inventory.snapshot() == after);
    CHECK(!s.inventory.abort(prepared.changes));
    CHECK(s.inventory.prepare(request, s.access).result.applied());
    CHECK(!s.inventory.prepare(request, s.access).changes);

    // Busy did not consume the other account's action sequence.
    contender.moves = {move(*after, id(101), id(20), 5)};
    CHECK(s.inventory.apply(contender, other).applied());
    auto nextRequest = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(10))});
    auto next = s.inventory.prepare(nextRequest, s.access);
    CHECK(next.changes);
    auto current = s.inventory.snapshot();
    CHECK(s.inventory.apply(request, s.access).sequence == 1);
    CHECK(s.inventory.commit(prepared.changes).sequence == 1);
    CHECK(s.inventory.snapshot() == current);
    CHECK(s.inventory.commit(next.changes).applied());
}

void prepared_abort() {
    Scenario s;
    auto before = s.inventory.snapshot();
    auto part = move(*before, id(100), id(20)); part.quantity = 7;
    auto request = s.request(Operation::Split, {part});
    auto first = s.inventory.prepare(request, s.access);
    CHECK(first.changes && first.changes->outcome.created);
    auto firstId = first.changes->outcome.created;
    Inventory foreign(catalog(), seed(), 1, 1);
    CHECK(foreign.commit(first.changes).code == Error::InvalidRequest);
    CHECK(!foreign.abort(first.changes));
    CHECK(s.inventory.commit({}).code == Error::InvalidRequest);
    CHECK(!s.inventory.abort({}));
    auto forged = std::make_shared<const WriteSet>(*first.changes);
    CHECK(s.inventory.commit(forged).code == Error::InvalidRequest);
    CHECK(!s.inventory.abort(forged));
    CHECK(s.inventory.abort(first.changes));
    CHECK(!s.inventory.abort(first.changes));
    CHECK(s.inventory.snapshot() == before);
    CHECK(s.inventory.commit(first.changes).code == Error::InvalidRequest);

    // Same action/request can retry after definite abort; exposed IDs are burned.
    auto retry = s.inventory.prepare(request, s.access);
    CHECK(retry.changes && retry.changes != first.changes);
    CHECK(retry.changes->outcome.created != firstId);
    CHECK(retry.changes->outcome.sequence == 0 && retry.changes->event == 2);
    CHECK(s.inventory.commit(first.changes).code == Error::InvalidRequest);
    CHECK(s.inventory.snapshot() == before);
    CHECK(s.inventory.commit(retry.changes).applied());
    CHECK(!s.inventory.snapshot()->items.contains(firstId));
    CHECK(s.inventory.snapshot()->items.at(retry.changes->outcome.created).quantity == 7);
    CHECK(s.inventory.commit(first.changes).code == Error::InvalidRequest);
    CHECK(s.inventory.snapshot()->items.at(id(100)).quantity == 13);
}

void prepared_rejections() {
    Scenario s;
    auto before = s.inventory.snapshot();
    auto request = s.request(Operation::Move, {
        move(*before, id(100), id(20)), move(*before, id(101), id(20), UINT16_MAX)});
    auto prepared = s.inventory.prepare(request, s.access);
    CHECK(prepared.changes && prepared.result.code == Error::Pending);
    CHECK(prepared.changes->outcome.code == Error::InvalidPlacement);
    CHECK(prepared.changes->items.empty() && prepared.changes->containers.empty());
    CHECK(prepared.changes->placements.empty());
    CHECK(s.inventory.snapshot() == before);
    CHECK(s.inventory.abort(prepared.changes));
    prepared = s.inventory.prepare(request, s.access);
    CHECK(prepared.changes);
    auto rejected = s.inventory.commit(prepared.changes);
    CHECK(rejected.code == Error::InvalidPlacement && rejected.sequence == 0);
    CHECK(s.inventory.snapshot() == before);
    CHECK(s.inventory.apply(request, s.access).code == Error::InvalidPlacement);
    auto valid = s.request(Operation::Move, {move(*before, id(100), id(20))});
    CHECK(s.inventory.apply(valid, s.access).applied());

    // Out-of-sequence admission must not allocate accounts or block valid work.
    Scenario limited;
    auto wrong = request; wrong.actionSeq = 2;
    for (unsigned i = 0; i < 100; ++i) {
        auto access = limited.access; access.account = {99, i + 1};
        CHECK(limited.inventory.prepare(wrong, access).result.code == Error::SequenceMismatch);
    }
    auto ok = limited.request(Operation::Move, {move(*limited.inventory.snapshot(), id(100), id(20))});
    CHECK(limited.inventory.apply(ok, limited.access).applied());
}

void write_set_contents() {
    Scenario s;
    auto before = s.inventory.snapshot();
    auto part = move(*before, id(100), id(20)); part.quantity = 7;
    auto split = s.inventory.prepare(s.request(Operation::Split, {part}), s.access);
    auto created = split.changes->outcome.created;
    CHECK(split.changes->items.size() == 2 && split.changes->placements.size() == 1);
    CHECK(!split.changes->items.at(created).before && split.changes->items.at(created).after);
    CHECK(split.changes->items.at(created).after->birthEvent == 1);
    CHECK(!split.changes->placements.at(created).before);
    CHECK(s.inventory.commit(split.changes).applied());
    CHECK(*s.inventory.snapshot() == replay(*before, *split.changes));
    before = s.inventory.snapshot();
    auto merge = s.inventory.prepare(s.request(Operation::Merge, {move(*before, created, id(10), 0)}), s.access);
    CHECK(merge.changes->items.size() == 2);
    CHECK(merge.changes->items.at(created).after->flags & deleted);
    CHECK(merge.changes->items.at(created).after->quantity == 0);
    CHECK(merge.changes->placements.at(created).before && !merge.changes->placements.at(created).after);
    CHECK(s.inventory.commit(merge.changes).applied());
    CHECK(*s.inventory.snapshot() == replay(*before, *merge.changes));

    // An unchanged child's new depth is also part of the write-set.
    auto world = seed();
    add_item(world, 200, 2, 1, 20, 4);
    world.containers.emplace(id(50), container(50, id(200)));
    Inventory nested(catalog(), world, 1, 1);
    before = nested.snapshot();
    Request nestedMove{{66, 1}, 1, Operation::Move, {move(*before, id(102), id(50), 0)}, 0, 99};
    auto pending = nested.prepare(nestedMove, s.access);
    CHECK(pending.changes->outcome.applied());
    CHECK((pending.changes->roots == std::vector<Id>{id(10), id(20)}));
    CHECK(pending.changes->containers.size() == 4);
    CHECK(pending.changes->containers.at(id(40)).before->state.depth == 1);
    CHECK(pending.changes->containers.at(id(40)).after->state.depth == 2);
    CHECK(pending.changes->containers.at(id(40)).after->state.revision == 2);
    CHECK(nested.commit(pending.changes).applied());
    CHECK(*nested.snapshot() == replay(*before, *pending.changes));
}

void prepared_concurrency() {
    Scenario s;
    auto before = s.inventory.snapshot();
    std::barrier start(20);
    std::vector<Preparation> preparations(20);
    std::vector<std::jthread> threads;
    for (unsigned i = 0; i < 20; ++i) {
        threads.emplace_back([&, i] {
            Request r{{99, i + 1}, 1, Operation::Move, {move(*before, id(100), id(20))}, 0, 99};
            auto access = s.access; access.account = {90, i + 1};
            start.arrive_and_wait();
            preparations[i] = s.inventory.prepare(r, access);
        });
    }
    threads.clear();
    std::shared_ptr<const WriteSet> winner;
    unsigned busy = 0;
    for (const auto& p : preparations) {
        if (p.changes) { CHECK(!winner); winner = p.changes; }
        else { CHECK(p.result.code == Error::Busy); ++busy; }
    }
    CHECK(winner && busy == 19 && s.inventory.snapshot() == before);
    std::atomic<unsigned> committed{};
    for (unsigned i = 0; i < 20; ++i) {
        threads.emplace_back([&] {
            start.arrive_and_wait();
            auto result = s.inventory.commit(winner);
            if (result.applied() && result.sequence == 1) ++committed;
        });
    }
    threads.clear();
    CHECK(committed == 20);
    CHECK(s.inventory.snapshot()->items.at(id(100)).revision == 2);
    CHECK(*s.inventory.snapshot() == replay(*before, *winner));
}
