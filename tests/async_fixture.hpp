#pragma once
#include "scenario.hpp"
#include "async_store.hpp"
#include <atomic>

struct StoreProbe {
    std::thread::id caller{std::this_thread::get_id()}, worker;
    std::mutex mutex;
    std::condition_variable wake;
    bool hold{};
    std::atomic<bool> entered{}, inspectFails{}, lost{}, aborted{}, closeFails{};
    std::atomic<unsigned> saves{}, closes{};
    void release() { std::lock_guard lock(mutex); hold = false; wake.notify_all(); }
};
class ProbeStore : public DurableStore {
    std::shared_ptr<StoreProbe> p_;
    StoredWorld saved_;
    void worker() { CHECK(std::this_thread::get_id() == p_->worker && p_->worker != p_->caller); }
public:
    explicit ProbeStore(std::shared_ptr<StoreProbe> p) : p_(std::move(p)) { p_->worker = std::this_thread::get_id(); }
    StoredWorld acquire(const Checkpoint& seed) override {
        worker(); saved_.checkpoint = seed; ++saved_.checkpoint.epoch; ++saved_.checkpoint.origin;
        saved_.checkpoint.nextId = saved_.checkpoint.nextEvent = 1; return saved_;
    }
    SaveOutcome save(std::uint64_t v, const Checkpoint& c, const SavedRequest&) override {
        worker(); ++p_->saves;
        { std::unique_lock lock(p_->mutex); p_->entered = true;
          CHECK(p_->wake.wait_for(lock, std::chrono::seconds(5), [&] { return !p_->hold; })); }
        if (p_->aborted) return SaveOutcome::Aborted;
        saved_ = {c, v + 1};
        if (p_->lost) throw Violation{Error::StorageUnavailable};
        return SaveOutcome::Committed;
    }
    StoredWorld inspect() override { worker(); require(!p_->inspectFails, Error::StorageUnavailable); return saved_; }
    void close() override { worker(); ++p_->closes; require(!p_->closeFails, Error::StorageUnavailable); }
};
struct AsyncScenario {
    std::shared_ptr<StoreProbe> probe = std::make_shared<StoreProbe>();
    AsyncStore* store{};
    std::unique_ptr<DurableInventory> inventory;
    AsyncScenario() {
        auto c = Inventory(catalog(), seed(), 1, 1).checkpoint();
        auto driver = std::make_unique<AsyncStore>([p = probe] { return std::make_unique<ProbeStore>(p); }, c);
        store = driver.get(); eventually([&] { return store->ready(); });
        inventory = std::make_unique<DurableInventory>(std::move(driver), c);
    }
    ~AsyncScenario() { probe->release(); }
    Access access() { return {{77,1}, inventory->epoch(), 99, {id(10),id(20),id(30)}}; }
    Request request() {
        auto part = move(*inventory->snapshot(), id(100), id(20)); part.quantity = 7;
        return {{88,1},1,Operation::Split,{part},0,99};
    }
};
