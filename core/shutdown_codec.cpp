#include "shutdown.hpp"
#include "packet_wire.hpp"
#include "wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode_shutdown(PacketHeader h, std::uint64_t sequence, std::size_t budget) {
    require(sequence <= revision_limit, Error::InvalidRequest);
    Writer w; w.put(sequence, 8);
    return packet_wire::wrap(h, w.bytes, MessageType::SessionClosing, budget);
}
std::uint64_t decode_shutdown(const std::vector<std::uint8_t>& bytes,
                              std::uint64_t epoch, std::size_t budget) {
    auto h = packet_wire::read(bytes, epoch, MessageType::SessionClosing, budget);
    require(h.payloadBytes == 8, Error::InvalidRequest);
    Reader r{bytes, packet_header_bytes}; auto sequence = r.get(8);
    require(sequence <= revision_limit, Error::InvalidRequest);
    return sequence;
}
}
