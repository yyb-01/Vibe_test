#include "async_fixture.hpp"
#include "allocation_probe.hpp"
#include <limits>

static std::pair<std::size_t, std::size_t> submit(unsigned tombstones) {
    auto world = seed();
    for (unsigned n = 0; n < tombstones; ++n) {
        ItemState item; item.id = id(100000 + n); item.defId = 1; item.flags = deleted; item.quantity = 0;
        world.items.emplace(item.id, item);
    }
    AsyncScenario s(Inventory(catalog(), std::move(world), 1, 1).checkpoint());
    auto request = s.request(); auto access = s.access();
    { std::lock_guard lock(s.probe->mutex); s.probe->hold = true; }
    std::size_t allocations;
    {
        allocation_probe::Scope scope(std::numeric_limits<std::size_t>::max());
        CHECK(s.inventory->apply(request, access).code == Error::Pending);
        allocations = scope.count();
    }
    auto bytes = s.store->status().bytes;
    CHECK(bytes < 8192);
    s.probe->release();
    eventually([&] { s.store->ready(); return !s.store->status().busy; });
    {
        allocation_probe::Scope scope(0);
        CHECK(s.inventory->resolve().applied());
        CHECK(scope.count() == 0);
    }
    Result closed;
    eventually([&] { closed = s.inventory->close(); return closed.code != Error::Pending; });
    CHECK(closed.applied());
    return {allocations, bytes};
}
void async_deltas() {
    // Unrelated rows must not increase owner allocations or the save mailbox size.
    CHECK(submit(0) == submit(10000));
    AsyncScenario s;
    CheckpointDelta delta;
    {
        allocation_probe::Scope scope(0);
        CHECK(s.store->save_delta(0, delta) == SaveOutcome::Aborted);
    }
    CHECK(!s.store->status().busy && s.probe->saves == 0);
    CHECK(s.inventory->apply(s.request(), s.access()).code == Error::Pending);
    Result result;
    eventually([&] { result = s.inventory->resolve(); return result.code != Error::Pending; });
    CHECK(result.applied());
    eventually([&] { result = s.inventory->close(); return result.code != Error::Pending; });
    CHECK(result.applied());
    for (bool epoch : {false, true}) {
        AsyncScenario fault;
        fault.probe->lost = true;
        fault.probe->fenced = epoch; fault.probe->changed = !epoch;
        auto before = fault.inventory->snapshot();
        CHECK(fault.inventory->apply(fault.request(), fault.access()).code == Error::Pending);
        eventually([&] { result = fault.inventory->resolve(); return result.code != Error::Pending; });
        CHECK(result.code == Error::EpochMismatch && fault.inventory->snapshot() == before);
        CHECK(fault.probe->saves == 1 && fault.inventory->close().code == Error::EpochMismatch);
    }
}
