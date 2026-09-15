#pragma once
#include "packet.hpp"

namespace astra {
enum class TransactionStatus : std::uint8_t { Pending, Committed, Rejected, Resolving };
// Public wire IDs are independent of internal Error enum values.
enum class ClientReason : std::uint16_t {
    None, RevisionConflict, Busy, InvalidPlacement, CapacityExceeded, CycleDetected,
    NotAccessible, MissingPart, InvalidQuantity, IdempotencyMismatch, PersistenceUnavailable
};
struct TransactionReceipt {
    Id requestId;
    TransactionStatus status{TransactionStatus::Pending};
    ClientReason reason{ClientReason::None};
    std::uint64_t commitSequence{}, durableWorldEpoch{};
    bool operator==(const TransactionReceipt&) const = default;
};
struct ReceiptPacket { PacketHeader header; TransactionReceipt receipt; };
// Only pass a durable/session Result, never a memory-only Inventory::apply result.
// Status-only receipt: changedCount=0. Committed requires an authorized view refresh.
TransactionReceipt make_receipt(Id requestId, const Result&, std::uint64_t epoch);
void validate_receipt(const TransactionReceipt&);
std::vector<std::uint8_t> encode_receipt(PacketHeader, const TransactionReceipt&,
                                        std::size_t pathBudget = datagram_limit);
ReceiptPacket decode_receipt(const std::vector<std::uint8_t>&, std::uint64_t expectedEpoch,
                             std::size_t pathBudget = datagram_limit);
}
