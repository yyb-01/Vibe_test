#pragma once
#include "fire_session.hpp"
#include "receipt.hpp"

namespace astra {
// Visual launch only; damage continues to use unquantized, host-owned ShotData.
struct ShotAccepted {
    std::uint64_t shotId{}, assemblyRevision{};
    std::uint32_t fireSeq{}, launchTick{}, ammoDef{}, visualSeed{};
    std::array<std::int16_t, 3> cell{}, direction{};
    std::array<std::uint32_t, 3> localPosition{}; // Micrometres within a 125 m cell.
    std::uint16_t speed{}; // 0.1 m/s; direction is signed normalized 32767.
    bool operator==(const ShotAccepted&) const = default;
};
struct FireReceipt {
    std::uint32_t fireSeq{};
    TransactionStatus status{TransactionStatus::Pending};
    ClientReason reason{ClientReason::None};
    std::optional<ShotAccepted> accepted;
    bool operator==(const FireReceipt&) const = default;
};
struct FireReceiptPacket { PacketHeader header; FireReceipt receipt; };
ShotAccepted visual_shot(std::uint64_t shotId, const ShotData&);
void validate_fire_receipt(const FireReceipt&);
FireReceipt make_fire_receipt(std::uint32_t fireSeq, const FireResult&, std::uint64_t epoch);
std::vector<std::uint8_t> encode_fire_receipt(PacketHeader, const FireReceipt&, std::size_t budget = datagram_limit);
FireReceiptPacket decode_fire_receipt(const std::vector<std::uint8_t>&, std::uint64_t epoch,
                                    std::size_t budget = datagram_limit);
}
