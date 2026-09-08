#include "async_fixture.hpp"
void async_budget_rollback();

void async_limits() {
    async_budget_rollback();
    using namespace std::chrono;
    CHECK(queue_pressure(250ms, false) == QueuePressure::Normal);
    CHECK(queue_pressure(251ms, false) == QueuePressure::Warning);
    CHECK(queue_pressure(1000ms, false) == QueuePressure::Warning);
    CHECK(queue_pressure(1001ms, false) == QueuePressure::Throttled);
    CHECK(queue_pressure(2000ms, false) == QueuePressure::Throttled);
    CHECK(queue_pressure(2001ms, false) == QueuePressure::Stopped);
    CHECK(queue_pressure(0ms, true) == QueuePressure::Stopped);
    auto p = std::make_shared<StoreProbe>();
    StoreWorker worker([p] { return std::make_unique<ProbeStore>(p); });
    StoreMessage tooLarge; tooLarge.bytes.resize(db_message_limit + 1);
    rejects([&] { worker.send(std::move(tooLarge)); }, Error::LimitExceeded);
    auto seed = Inventory(catalog(), ::seed(), 1, 1).checkpoint();
    CHECK(worker.send({StoreCommand::Acquire, encode_checkpoint(seed), 0, {}}));
    CHECK(!worker.send({StoreCommand::Inspect, {}, 0, {}}));
    std::optional<StoreMessage> reply;
    eventually([&] { reply = worker.take(); return reply.has_value(); });
    CHECK(!reply->failure && decode_checkpoint(reply->bytes).epoch == 2);
    AsyncScenario s; std::atomic<bool> rejected{};
    std::thread other([&] { try { s.store->status(); } catch (const Violation& e) { rejected = e.code == Error::InvalidState; } });
    other.join(); CHECK(rejected);
    AsyncStore bad([]() -> std::unique_ptr<DurableStore> { throw Violation{Error::Incompatible}; }, seed);
    bool startupFailed = false;
    eventually([&] {
        try { bad.ready(); } catch (const Violation& e) { CHECK(e.code == Error::Incompatible); startupFailed = true; }
        return startupFailed;
    });
}
void async_rollback() {
    AsyncScenario s; auto& i = *s.inventory; auto request = s.request();
    s.probe->aborted = true;
    CHECK(i.apply(request, s.access()).code == Error::Pending);
    Result result;
    eventually([&] { result = i.resolve(); return result.code != Error::Pending; });
    CHECK(result.code == Error::StorageUnavailable && i.snapshot()->items.at(id(100)).quantity == 20);
    s.probe->aborted = false;
    CHECK(i.apply(request, s.access()).code == Error::Pending);
    eventually([&] { result = i.resolve(); return result.code != Error::Pending; });
    CHECK(result.applied() && result.sequence == 1);
    eventually([&] { return i.close().code != Error::Pending; });
}
