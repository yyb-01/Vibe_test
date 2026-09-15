#include "scenario.hpp"
#include "receipt.hpp"

void receipt_reasons() {
    using S = TransactionStatus; using R = ClientReason;
    const std::pair<S, R> expected[]{
        {S::Committed,R::None}, {S::Rejected,R::NotAccessible}, {S::Rejected,R::NotAccessible},
        {S::Resolving,R::PersistenceUnavailable}, {S::Rejected,R::RevisionConflict},
        {S::Rejected,R::IdempotencyMismatch}, {S::Rejected,R::RevisionConflict},
        {S::Rejected,R::InvalidQuantity}, {S::Rejected,R::InvalidPlacement},
        {S::Rejected,R::CapacityExceeded}, {S::Rejected,R::CycleDetected},
        {S::Rejected,R::InvalidPlacement}, {S::Resolving,R::PersistenceUnavailable},
        {S::Resolving,R::PersistenceUnavailable}, {S::Resolving,R::Busy},
        {S::Pending,R::None}, {S::Resolving,R::Busy}, {S::Resolving,R::PersistenceUnavailable}
    };
    static_assert(std::size(expected) == static_cast<unsigned>(Error::StorageUnavailable) + 1);
    PacketHeader header; header.worldEpoch = 1; header.messageType = MessageType::InventoryReceipt;
    for (unsigned n = 0; n < std::size(expected); ++n) {
        auto r = make_receipt(id(1), {static_cast<Error>(n), 9, {}}, 1);
        CHECK(r.status == expected[n].first && r.reason == expected[n].second);
        CHECK(r.commitSequence == (n == 0 ? 9 : 0));
        CHECK(decode_receipt(encode_receipt(header, r), 1).receipt == r);
    }
    CHECK(make_receipt(id(1), {static_cast<Error>(255), 9, {}}, 1).status == S::Resolving);
}
