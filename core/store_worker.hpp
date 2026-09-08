#pragma once
#include "durable.hpp"
#include <condition_variable>
#include <functional>
#include <optional>
#include <thread>

namespace astra {
inline constexpr std::size_t db_queue_limit = 64 * 1024 * 1024;
// Reserve fixed mailbox/thread bookkeeping; decoded worlds are execution memory.
inline constexpr std::size_t db_message_limit = db_queue_limit - 4096;
using StoreFactory = std::function<std::unique_ptr<DurableStore>()>;
enum class StoreCommand { Acquire, Save, Inspect, Close };
struct StoreMessage {
    StoreCommand command{};
    std::vector<std::uint8_t> bytes;
    std::uint64_t version{};
    std::exception_ptr failure;
};
// ponytail: one in-flight checkpoint; expand the queue after row-delta persistence.
class StoreWorker {
public:
    explicit StoreWorker(StoreFactory);
    ~StoreWorker(); // Joins: destroy only outside the game tick after close completes.
    bool send(StoreMessage);
    std::optional<StoreMessage> take();
private:
    void run(StoreFactory);
    std::mutex mutex_;
    std::condition_variable wake_;
    std::optional<StoreMessage> job_, reply_;
    bool occupied_{}, stopping_{};
    std::thread thread_;
};
}
