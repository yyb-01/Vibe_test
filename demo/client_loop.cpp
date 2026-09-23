#include "client.hpp"
#include <thread>

void ConsoleClient::tick() {
    if (!transport_ || !transport_->connection()) return;
    try {
        transport_tick(*transport_, client_, token_, observation());
        require(connected(), Error::NotAccessible);
    } catch (...) { lease_ = 0; throw; }
}

void ConsoleClient::exchange(bool snapshot, bool closing) {
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    try {
        for (;;) {
            auto moved = transport_tick(*transport_, client_, token_, observation());
            if (closing && !transport_->connection()) return;
            require(transport_->connection() && client_.poll(token_), Error::NotAccessible);
            if (connected() && transport_->output().empty() && client_.output(token_).empty() &&
                (!snapshot || client_.state().view())) return;
            require(std::chrono::steady_clock::now() < deadline, Error::Busy);
            if (!moved) std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
    } catch (...) { transport_->disconnect(); client_.disconnect(token_); lease_ = 0; throw; }
}
Result ConsoleClient::result() {
    const auto& receipt = client_.state().status(request_->id);
    if (receipt.status == TransactionStatus::Pending || receipt.status == TransactionStatus::Resolving)
        return {Error::Pending, 0, {}};
    if (receipt.status == TransactionStatus::Committed) {
        // Diagnostic created ID is host-local; success is established by the wire receipt first.
        auto saved = inventory_.result_for(*request_, {77, 1});
        require(saved && saved->applied() && saved->sequence == receipt.commitSequence, Error::InvalidState);
        return *saved;
    }
    constexpr Error reasons[]{Error::InvalidState, Error::RevisionConflict, Error::Busy,
        Error::InvalidPlacement, Error::CapacityExceeded, Error::CycleDetected, Error::NotAccessible,
        Error::InvalidRequest, Error::InvalidQuantity, Error::IdempotencyMismatch, Error::StorageUnavailable};
    return {reasons[static_cast<unsigned>(receipt.reason)], 0, {}};
}
