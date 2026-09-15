#include "packet_wire.hpp"
#include "wire.hpp"
#include <algorithm>

namespace astra::packet_wire {
static void validate(const PacketHeader& h, MessageType expected) {
    require(h.protocolVersion == protocol_version &&
            h.messageType == expected, Error::Incompatible);
    require(h.worldEpoch && h.worldEpoch <= revision_limit && !h.flags, Error::InvalidRequest);
}
std::vector<std::uint8_t> wrap(PacketHeader h, const std::vector<std::uint8_t>& payload, MessageType expected, std::size_t budget) {
    validate(h, expected);

    require(budget >= packet_header_bytes && payload.size() <= std::min(budget, datagram_limit) - packet_header_bytes, Error::LimitExceeded);
    h.payloadBytes = static_cast<std::uint16_t>(payload.size());
    Writer w;
    w.bytes.reserve(packet_header_bytes + payload.size());
    w.put(h.protocolVersion, 2); w.put(static_cast<unsigned>(h.messageType), 2);
    w.put(h.worldEpoch, 8); w.put(h.sequence, 4); w.put(h.ackSequence, 4);
    w.put(h.ackBits, 4); w.put(h.senderTick, 4);
    w.put(h.payloadBytes, 2); w.put(h.flags, 2);
    w.bytes.insert(w.bytes.end(), payload.begin(), payload.end());
    return w.bytes;
}
PacketHeader read(const std::vector<std::uint8_t>& bytes,
                                std::uint64_t epoch, MessageType expected, std::size_t budget) {
    require(bytes.size() >= packet_header_bytes && bytes.size() <= std::min(budget, datagram_limit),
            Error::InvalidRequest);
    Reader r{bytes}; PacketHeader h;
    h.protocolVersion = static_cast<std::uint16_t>(r.get(2));
    h.messageType = static_cast<MessageType>(r.get(2)); h.worldEpoch = r.get(8);
    h.sequence = static_cast<std::uint32_t>(r.get(4));
    h.ackSequence = static_cast<std::uint32_t>(r.get(4));
    h.ackBits = static_cast<std::uint32_t>(r.get(4));
    h.senderTick = static_cast<std::uint32_t>(r.get(4));
    h.payloadBytes = static_cast<std::uint16_t>(r.get(2));
    h.flags = static_cast<std::uint16_t>(r.get(2)); validate(h, expected);
    require(h.worldEpoch == epoch, Error::EpochMismatch);
    require(h.payloadBytes == bytes.size() - packet_header_bytes, Error::InvalidRequest);
    return h;
}
}
