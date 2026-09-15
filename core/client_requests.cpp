#include "client_state.hpp"
#include "inventory.hpp"
#include <algorithm>

namespace astra {
static bool final(TransactionStatus s) {
    return s == TransactionStatus::Committed || s == TransactionStatus::Rejected;
}
ClientState::ClientState(std::uint64_t epoch, Catalog catalog) : epoch_(epoch), catalog_(std::move(catalog)) {
    require(epoch && epoch <= revision_limit, Error::InvalidState);
    verify_world(catalog_, {});
}
const ClientState::Tracked& ClientState::tracked(Id id) const {
    auto it = requests_.find(id); require(it != requests_.end(), Error::InvalidRequest); return it->second;
}
ClientState::Tracked& ClientState::tracked(Id id) {
    auto it = requests_.find(id); require(it != requests_.end(), Error::InvalidRequest); return it->second;
}
void ClientState::track(const Request& request) {
    require(connected_, Error::NotAccessible);
    require(bool(request.id) && request.actionSeq && request.actionSeq <= revision_limit &&
            request.interactionLease, Error::InvalidRequest);
    auto payload = encode(request);
    if (auto it = requests_.find(request.id); it != requests_.end()) {
        require(it->second.payload == payload, Error::IdempotencyMismatch); return;
    }
    require(requests_.size() < 8, Error::Busy);
    requests_.emplace(request.id, Tracked{std::move(payload),
        {request.id, TransactionStatus::Pending, ClientReason::None, 0, epoch_}});
}
void ClientState::forget(Id id) {
    require(final(tracked(id).receipt.status), Error::Busy); requests_.erase(id);
}
const TransactionReceipt& ClientState::status(Id id) const { return tracked(id).receipt; }
const std::vector<std::uint8_t>& ClientState::retry_payload(Id id) const { return tracked(id).payload; }
void ClientState::timeout(Id id) {
    auto& r = tracked(id).receipt;
    if (!final(r.status)) { r.status = TransactionStatus::Resolving; r.reason = ClientReason::PersistenceUnavailable; }
}
bool ClientState::receive_receipt(const std::vector<std::uint8_t>& bytes) {
    require(connected_, Error::NotAccessible);
    auto incoming = decode_receipt(bytes, epoch_).receipt;
    auto it = requests_.find(incoming.requestId);
    if (it == requests_.end()) return false;
    auto& current = it->second.receipt;
    if (final(current.status)) {
        if (final(incoming.status)) require(current == incoming, Error::InvalidState);
        return false;
    }
    if (current.status == TransactionStatus::Resolving && incoming.status == TransactionStatus::Pending) return false;
    if (current == incoming) return false;
    current = incoming;
    confirmed_ = std::max(confirmed_, incoming.commitSequence);
    if (latest_ && latest_->sequence < confirmed_) assembly_.reset();
    return true;
}
}
