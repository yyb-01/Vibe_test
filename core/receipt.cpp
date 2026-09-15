#include "receipt.hpp"

namespace astra {
TransactionReceipt make_receipt(Id id, const Result& result, std::uint64_t epoch) {
    TransactionReceipt r{id, TransactionStatus::Rejected, ClientReason::None, 0, epoch};
    switch (result.code) {
    case Error::Ok: r.status = TransactionStatus::Committed; r.commitSequence = result.sequence; break;
    case Error::Pending: r.status = TransactionStatus::Pending; break;
    case Error::RevisionConflict: case Error::SequenceMismatch: r.reason = ClientReason::RevisionConflict; break;
    case Error::InvalidPlacement: case Error::DepthExceeded: r.reason = ClientReason::InvalidPlacement; break;
    case Error::CapacityExceeded: r.reason = ClientReason::CapacityExceeded; break;
    case Error::CycleDetected: r.reason = ClientReason::CycleDetected; break;
    case Error::NotAccessible: case Error::InvalidRequest: r.reason = ClientReason::NotAccessible; break;
    case Error::InvalidQuantity: r.reason = ClientReason::InvalidQuantity; break;
    case Error::IdempotencyMismatch: r.reason = ClientReason::IdempotencyMismatch; break;
    case Error::Busy: case Error::LimitExceeded:
        r.status = TransactionStatus::Resolving; r.reason = ClientReason::Busy; break;
    default: // Unknown storage/epoch/internal outcomes cannot prove a rejection.
        r.status = TransactionStatus::Resolving; r.reason = ClientReason::PersistenceUnavailable; break;
    }
    validate_receipt(r); return r;
}
void validate_receipt(const TransactionReceipt& r) {
    require(bool(r.requestId) && r.durableWorldEpoch && r.durableWorldEpoch <= revision_limit &&
            r.commitSequence <= revision_limit, Error::InvalidRequest);
    require(static_cast<unsigned>(r.reason) <= static_cast<unsigned>(ClientReason::PersistenceUnavailable),
            Error::InvalidRequest);
    switch (r.status) {
    case TransactionStatus::Committed:
        require(r.commitSequence && r.reason == ClientReason::None, Error::InvalidRequest); break;
    case TransactionStatus::Pending:
        require(!r.commitSequence && r.reason == ClientReason::None, Error::InvalidRequest); break;
    case TransactionStatus::Rejected:
        require(!r.commitSequence && r.reason != ClientReason::None &&
                r.reason != ClientReason::Busy && r.reason != ClientReason::PersistenceUnavailable,
                Error::InvalidRequest); break;
    case TransactionStatus::Resolving:
        require(!r.commitSequence && (r.reason == ClientReason::Busy ||
                r.reason == ClientReason::PersistenceUnavailable), Error::InvalidRequest); break;
    default: throw Violation{Error::InvalidRequest};
    }
}
}
