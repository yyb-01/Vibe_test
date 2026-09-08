#include "async_store.hpp"

namespace astra {
AsyncStore::AsyncStore(StoreFactory factory, const Checkpoint& seed) : worker_(std::move(factory)) {
    send({StoreCommand::Acquire, encode_checkpoint(seed), 0, {}});
}
void AsyncStore::owner() const { require(std::this_thread::get_id() == owner_, Error::InvalidState); }
void AsyncStore::send(StoreMessage message) {
    require(!running_, Error::Busy);
    auto capacity = message.bytes.capacity();
    auto command = message.command;
    reply_.reset();
    require(worker_.send(std::move(message)), Error::Busy);
    active_ = command; running_ = true; bytes_ = capacity + 4096;
    if (!uncertain_) started_ = std::chrono::steady_clock::now();
}
void AsyncStore::collect() {
    if (!running_) return;
    auto result = worker_.take();
    if (!result) return;
    reply_ = std::move(result); running_ = false;
    bytes_ = reply_->bytes.capacity() + 4096;
}
QueueStatus AsyncStore::status() const {
    owner();
    auto age = (running_ || uncertain_) ? std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - started_) : std::chrono::milliseconds{};
    return {running_, uncertain_, bytes_, age, queue_pressure(age, uncertain_)};
}
bool AsyncStore::ready() {
    owner(); collect();
    if (acquired_) return true;
    if (running_) return false;
    require(reply_.has_value(), Error::InvalidState);
    if (reply_->failure) std::rethrow_exception(reply_->failure);
    return true;
}
StoredWorld AsyncStore::loaded() const {
    require(reply_.has_value(), Error::InvalidState);
    if (reply_->failure) std::rethrow_exception(reply_->failure);
    return {decode_checkpoint(reply_->bytes), reply_->version};
}
StoredWorld AsyncStore::acquire(const Checkpoint& seed) {
    owner(); require(!acquired_ && ready(), Error::Busy);
    auto result = loaded();
    require(result.checkpoint.catalog == seed.catalog, Error::Incompatible);
    acquired_ = true; reply_.reset(); bytes_ = 0;
    return result;
}
SaveOutcome AsyncStore::save(std::uint64_t version, const Checkpoint& target, const SavedRequest& record) {
    owner(); require(acquired_ && !closing_ && !running_ && !uncertain_, Error::Busy);
    require(!target.requests.empty(), Error::InvalidState);
    const auto& last = target.requests.back();
    require(last.account == record.account && last.requestId == record.requestId &&
        last.actionSeq == record.actionSeq && last.payload == record.payload &&
        last.result.code == record.result.code && last.result.sequence == record.result.sequence &&
        last.result.created == record.result.created, Error::InvalidState);
    auto bytes = encode_checkpoint(target);
    if (bytes.capacity() > db_message_limit) return SaveOutcome::Limited;
    send({StoreCommand::Save, std::move(bytes), version, {}});
    return SaveOutcome::Unknown;
}
}
