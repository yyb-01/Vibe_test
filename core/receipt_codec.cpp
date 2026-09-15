#include "receipt.hpp"
#include "packet_wire.hpp"
#include "wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode_receipt(PacketHeader h, const TransactionReceipt& receipt, std::size_t budget) {
    validate_receipt(receipt);
    require(h.worldEpoch == receipt.durableWorldEpoch, Error::EpochMismatch);
    Writer w; w.bytes.reserve(38);
    w.id(receipt.requestId); w.put(static_cast<unsigned>(receipt.status), 1);
    w.put(static_cast<unsigned>(receipt.reason), 2); w.put(0, 1);
    w.put(receipt.commitSequence, 8); w.put(receipt.durableWorldEpoch, 8); w.put(0, 2);
    return packet_wire::wrap(h, w.bytes, MessageType::InventoryReceipt, budget);
}
ReceiptPacket decode_receipt(const std::vector<std::uint8_t>& bytes, std::uint64_t epoch, std::size_t budget) {
    auto h = packet_wire::read(bytes, epoch, MessageType::InventoryReceipt, budget);
    require(h.payloadBytes == 38, Error::InvalidRequest);
    Reader reader{bytes, packet_header_bytes}; TransactionReceipt r;
    r.requestId = reader.id(); r.status = static_cast<TransactionStatus>(reader.get(1));
    r.reason = static_cast<ClientReason>(reader.get(2));
    require(reader.get(1) == 0, Error::InvalidRequest);
    r.commitSequence = reader.get(8); r.durableWorldEpoch = reader.get(8);
    require(reader.get(2) == 0, Error::InvalidRequest); // Inline changes are not implemented yet.
    validate_receipt(r);
    require(r.durableWorldEpoch == h.worldEpoch, Error::EpochMismatch);
    return {h, r};
}
}
