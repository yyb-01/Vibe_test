#include "client_state.hpp"
#include <algorithm>

namespace astra {
static bool final_fire(TransactionStatus s) {
    return s == TransactionStatus::Committed || s == TransactionStatus::Rejected;
}
void ClientState::track_fire(const FireIntent& intent) {
    require(connected_, Error::NotAccessible); validate_fire_intent(intent);
    auto found = fires_.find(intent.fireSeq);
    if (found != fires_.end()) {
        require(found->second.intent == intent, Error::IdempotencyMismatch);
        // Admission rejection is not a durable shot record; a new attempt needs a new sequence.
        require(found->second.receipt.status != TransactionStatus::Rejected, Error::InvalidState);
        return;
    }
    require(fires_.size() < 64, Error::Busy);
    fires_.emplace(intent.fireSeq, TrackedFire{intent,
        {intent.fireSeq, TransactionStatus::Pending, ClientReason::None, {}}});
}
const FireReceipt& ClientState::fire_status(std::uint32_t seq) const {
    auto it = fires_.find(seq); require(it != fires_.end(), Error::InvalidRequest); return it->second.receipt;
}
const FireIntent& ClientState::retry_fire(std::uint32_t seq) const {
    fire_status(seq); return fires_.at(seq).intent;
}
void ClientState::forget_fire(std::uint32_t seq) {
    require(final_fire(fire_status(seq).status), Error::Busy); fires_.erase(seq);
}
void ClientState::timeout_fire(std::uint32_t seq) {
    fire_status(seq); auto& r = fires_.at(seq).receipt;
    if (!final_fire(r.status)) { r.status = TransactionStatus::Resolving; r.reason = ClientReason::PersistenceUnavailable; }
}
bool ClientState::receive_fire_receipt(const std::vector<std::uint8_t>& bytes) {
    require(connected_, Error::NotAccessible);
    auto incoming = decode_fire_receipt(bytes, epoch_).receipt;
    auto it = fires_.find(incoming.fireSeq);
    if (it == fires_.end()) return false;
    if (incoming.accepted)
        require(incoming.accepted->assemblyRevision == it->second.intent.assemblyRevision, Error::InvalidState);
    auto& current = it->second.receipt;
    if (final_fire(current.status)) {
        if (final_fire(incoming.status)) require(current == incoming, Error::InvalidState);
        return false;
    }
    if (current.status == TransactionStatus::Resolving && incoming.status == TransactionStatus::Pending) return false;
    if (current == incoming) return false;
    current = incoming;
    if (incoming.accepted) {
        confirmed_ = std::max(confirmed_, incoming.accepted->shotId);
        if (latest_ && latest_->sequence < confirmed_) assembly_.reset();
    }
    return true;
}
}
