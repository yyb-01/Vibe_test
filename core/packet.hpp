#pragma once
#include "transaction.hpp"

namespace astra {
inline constexpr std::uint16_t protocol_version = 1;
inline constexpr std::size_t packet_header_bytes = 32, datagram_limit = 1200;
enum class MessageType : std::uint16_t {
    InventoryRequest = 1, InventoryReceipt = 2, SessionResume = 3, SessionClosing = 4
};
struct PacketHeader {
    std::uint16_t protocolVersion{protocol_version};
    MessageType messageType{MessageType::InventoryRequest};
    std::uint64_t worldEpoch{};
    std::uint32_t sequence{}, ackSequence{}, ackBits{}, senderTick{};
    std::uint16_t payloadBytes{}, flags{};
    bool operator==(const PacketHeader&) const = default;
};
struct TransactionPacket { PacketHeader header; Request request; };
// Call after transport authentication. Access/account/lease authority is never
// obtained from this header. pathBudget excludes encryption/transport overhead.
std::vector<std::uint8_t> encode_packet(PacketHeader, const Request&,
                                       std::size_t pathBudget = datagram_limit);
TransactionPacket decode_packet(const std::vector<std::uint8_t>&,
                                std::uint64_t expectedEpoch,
                                std::size_t pathBudget = datagram_limit);
// Valid for distances strictly less than half the uint32 range (ticks too).
inline bool serial_newer(std::uint32_t a, std::uint32_t b) {
    auto distance = std::uint32_t(a - b);
    return distance != 0 && distance < 0x80000000u;
}
struct PacketWindow {
    bool initialized{};
    std::uint32_t sequence{}, bits{};
    // Tracks latest + previous 32 packets; false means duplicate/too old.
    // Transaction retries must still reach durable requestId idempotency.
    bool observe(std::uint32_t incoming);
};
}
