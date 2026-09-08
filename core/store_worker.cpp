#include "store_worker.hpp"

namespace astra {
namespace {
void execute(DurableStore& store, StoreMessage& message) {
    if (message.command == StoreCommand::Close) { store.close(); return; }
    StoredWorld loaded;
    if (message.command == StoreCommand::Acquire) {
        loaded = store.acquire(decode_checkpoint(message.bytes));
    } else if (message.command == StoreCommand::Save) {
        auto target = decode_checkpoint(message.bytes);
        require(!target.requests.empty(), Error::InvalidState);
        SaveOutcome outcome = SaveOutcome::Unknown;
        try { outcome = store.save(message.version, target, target.requests.back()); } catch (...) {}
        if (outcome == SaveOutcome::Committed) { ++message.version; return; }
        loaded = store.inspect(); // Settle aborted/unknown/fenced results using durable state.
    } else loaded = store.inspect();
    std::vector<std::uint8_t>().swap(message.bytes);
    message.version = loaded.version;
    message.bytes = encode_checkpoint(loaded.checkpoint);
    require(message.bytes.capacity() <= db_message_limit, Error::LimitExceeded);
}
}
StoreWorker::StoreWorker(StoreFactory factory)
    : thread_([this, factory = std::move(factory)]() mutable { run(std::move(factory)); }) {
    static_assert(sizeof(StoreWorker) + 3 * sizeof(StoreMessage) < 4096);
}
StoreWorker::~StoreWorker() {
    { std::lock_guard lock(mutex_); stopping_ = true; }
    wake_.notify_one(); thread_.join();
}
bool StoreWorker::send(StoreMessage message) {
    require(message.bytes.capacity() <= db_message_limit, Error::LimitExceeded);
    std::lock_guard lock(mutex_);
    if (occupied_ || stopping_) return false;
    job_ = std::move(message); occupied_ = true;
    wake_.notify_one(); return true;
}
std::optional<StoreMessage> StoreWorker::take() {
    std::lock_guard lock(mutex_);
    if (!reply_) return {};
    auto result = std::move(reply_); reply_.reset(); occupied_ = false;
    return result;
}
void StoreWorker::run(StoreFactory factory) {
    std::unique_ptr<DurableStore> store;
    std::exception_ptr startup;
    try { store = factory(); require(bool(store), Error::InvalidState); }
    catch (...) { startup = std::current_exception(); }
    for (;;) {
        StoreMessage message;
        {
            std::unique_lock lock(mutex_);
            wake_.wait(lock, [&] { return stopping_ || job_.has_value(); });
            if (!job_) return;
            message = std::move(*job_); job_.reset();
        }
        try { if (startup) std::rethrow_exception(startup); execute(*store, message); }
        catch (...) { message.failure = std::current_exception(); std::vector<std::uint8_t>().swap(message.bytes); }
        { std::lock_guard lock(mutex_); reply_ = std::move(message); }
    }
}
}
