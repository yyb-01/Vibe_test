#include "fire_session.hpp"
#include "packet_wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode_fire_packet(PacketHeader header, const FireIntent& intent, std::size_t budget) {
    return packet_wire::wrap(header, encode_fire_intent(intent), MessageType::FireIntent, budget);
}
FirePacket decode_fire_packet(const std::vector<std::uint8_t>& bytes, std::uint64_t epoch, std::size_t budget) {
    auto header = packet_wire::read(bytes, epoch, MessageType::FireIntent, budget);
    return {header, decode_fire_intent({bytes.begin() + packet_header_bytes, bytes.end()})};
}
}
