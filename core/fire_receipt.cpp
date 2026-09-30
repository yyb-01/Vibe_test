#include "fire_receipt.hpp"
#include "packet_wire.hpp"
#include "wire.hpp"
#include <bit>

namespace astra {
FireReceipt make_fire_receipt(std::uint32_t seq, const FireResult& result, std::uint64_t epoch) {
    require(result.accepted.has_value() == result.result.applied(), Error::InvalidState);
    auto receipt = make_receipt({fire_request_namespace, seq}, result.result, epoch);
    FireReceipt r{seq, receipt.status, receipt.reason, {}};
    if (result.accepted) r.accepted = visual_shot(receipt.commitSequence, *result.accepted);
    validate_fire_receipt(r); return r;
}
std::vector<std::uint8_t> encode_fire_receipt(PacketHeader h, const FireReceipt& r, std::size_t budget) {
    validate_fire_receipt(r);
    Writer w; w.put(r.fireSeq, 4); w.put(static_cast<unsigned>(r.status), 1);
    w.put(static_cast<unsigned>(r.reason), 2); w.put(0, 1);
    if (r.accepted) {
        const auto& s = *r.accepted;
        w.put(s.shotId, 8); w.put(s.fireSeq, 4); w.put(s.launchTick, 4); w.put(s.assemblyRevision, 8);
        for (unsigned i = 0; i < 3; ++i) { w.put(static_cast<std::uint16_t>(s.cell[i]), 2); w.put(s.localPosition[i], 4); }
        for (auto axis : s.direction) w.put(static_cast<std::uint16_t>(axis), 2);
        w.put(s.speed, 2); w.put(s.ammoDef, 4); w.put(s.visualSeed, 4);
    }
    return packet_wire::wrap(h, w.bytes, MessageType::FireReceipt, budget);
}
FireReceiptPacket decode_fire_receipt(const std::vector<std::uint8_t>& bytes, std::uint64_t epoch, std::size_t budget) {
    auto h = packet_wire::read(bytes, epoch, MessageType::FireReceipt, budget);
    Reader reader{bytes, packet_header_bytes}; FireReceipt r;
    auto get = [&](unsigned n) { return reader.get(n); };
    auto signed16 = [&] { return std::bit_cast<std::int16_t>(static_cast<std::uint16_t>(get(2))); };
    r.fireSeq = static_cast<std::uint32_t>(get(4)); r.status = static_cast<TransactionStatus>(get(1));
    r.reason = static_cast<ClientReason>(get(2)); require(get(1) == 0, Error::InvalidRequest);
    if (r.status == TransactionStatus::Committed) {
        auto& s = r.accepted.emplace(); s.shotId = get(8); s.fireSeq = static_cast<std::uint32_t>(get(4));
        s.launchTick = static_cast<std::uint32_t>(get(4)); s.assemblyRevision = get(8);
        for (unsigned i = 0; i < 3; ++i) { s.cell[i] = signed16(); s.localPosition[i] = static_cast<std::uint32_t>(get(4)); }
        for (auto& axis : s.direction) axis = signed16();
        s.speed = static_cast<std::uint16_t>(get(2)); s.ammoDef = static_cast<std::uint32_t>(get(4));
        s.visualSeed = static_cast<std::uint32_t>(get(4));
    }
    require(reader.position == bytes.size(), Error::InvalidRequest);
    validate_fire_receipt(r); return {h, r};
}
}
