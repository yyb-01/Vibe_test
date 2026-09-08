#pragma once
#include "store_worker.hpp"
#include <chrono>

namespace astra {
enum class QueuePressure { Normal, Warning, Throttled, Stopped };
inline QueuePressure queue_pressure(std::chrono::milliseconds age, bool uncertain) {
    if (uncertain || age > std::chrono::seconds(2)) return QueuePressure::Stopped;
    if (age > std::chrono::seconds(1)) return QueuePressure::Throttled;
    if (age > std::chrono::milliseconds(250)) return QueuePressure::Warning;
    return QueuePressure::Normal;
}
struct QueueStatus {
    bool busy{}, uncertain{};
    std::size_t bytes{};
    std::chrono::milliseconds age{};
    QueuePressure pressure{};
};
// Owner-thread adapter. DB calls run on one worker; DurableInventory publishes on owner.
class AsyncStore final : public DurableStore {
public:
    AsyncStore(StoreFactory, const Checkpoint& seed);
    bool ready(); // Nonblocking startup poll; propagates recovery failure.
    QueueStatus status() const;
    StoredWorld acquire(const Checkpoint&) override;
    SaveOutcome save(std::uint64_t, const Checkpoint&, const SavedRequest&) override;
    StoredWorld inspect() override;
    void close() override;
private:
    void owner() const;
    void send(StoreMessage);
    void collect();
    StoredWorld loaded() const;
    const std::thread::id owner_{std::this_thread::get_id()};
    StoreWorker worker_;
    std::optional<StoreMessage> reply_;
    StoreCommand active_{StoreCommand::Acquire};
    std::chrono::steady_clock::time_point started_{};
    std::size_t bytes_{};
    bool running_{}, acquired_{}, uncertain_{}, closing_{}, closed_{};
};
}
