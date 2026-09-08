#include "async_fixture.hpp"

void async_publication() {
    AsyncScenario s; auto& i = *s.inventory; auto request = s.request();
    { std::lock_guard lock(s.probe->mutex); s.probe->hold = true; }
    auto old = i.snapshot();
    CHECK(i.apply(request, s.access()).code == Error::Pending);
    eventually([&] { return s.probe->entered.load(); });
    CHECK(s.store->status().busy && s.store->status().bytes <= db_queue_limit);
    CHECK(i.snapshot() == old && i.resolve().code == Error::Pending);
    auto other = request; other.id = {88,2};
    CHECK(i.apply(other, s.access()).code == Error::Busy);
    other = request; other.moves[0].quantity = 6;
    CHECK(i.apply(other, s.access()).code == Error::IdempotencyMismatch);
    CHECK(i.apply(request, s.access()).code == Error::Pending && s.probe->saves == 1);
    s.probe->release();
    eventually([&] { s.store->ready(); return !s.store->status().busy; });
    CHECK(i.snapshot() == old); // Worker finished; owner has not published yet.
    auto result = i.resolve();
    CHECK(result.applied() && result.sequence == 1);
    CHECK(i.snapshot()->items.at(id(100)).quantity == 13);
    CHECK(i.apply(request, s.access()).created == result.created && s.probe->saves == 1);
    Result closed;
    eventually([&] { closed = i.close(); return closed.code != Error::Pending; });
    CHECK(closed.applied() && s.probe->closes == 1);
    CHECK(i.close().applied() && i.apply(request, s.access()).code == Error::Busy);
}
void async_resolution() {
    AsyncScenario s; auto& i = *s.inventory; auto request = s.request();
    s.probe->lost = true; s.probe->inspectFails = true;
    CHECK(i.apply(request, s.access()).code == Error::Pending);
    eventually([&] { CHECK(i.resolve().code == Error::Pending); return s.store->status().uncertain; });
    CHECK(s.store->status().pressure == QueuePressure::Stopped);
    CHECK(i.snapshot()->items.at(id(100)).quantity == 20);
    CHECK(i.close().code == Error::Pending);
    s.probe->inspectFails = false; s.probe->closeFails = true;
    Result closed;
    eventually([&] { closed = i.close(); return closed.code != Error::Pending; });
    CHECK(closed.code == Error::StorageUnavailable && s.probe->saves == 1);
    CHECK(i.snapshot()->items.at(id(100)).quantity == 13);
    s.probe->closeFails = false;
    eventually([&] { closed = i.close(); return closed.code != Error::Pending; });
    CHECK(closed.applied());
}
