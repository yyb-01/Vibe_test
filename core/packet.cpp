#include "packet_wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode_packet(PacketHeader h, const Request& request, std::size_t budget) {
    require(request.operation != Operation::Fire, Error::InvalidRequest);
    return packet_wire::wrap(h, encode(request), MessageType::InventoryRequest, budget);
}
TransactionPacket decode_packet(const std::vector<std::uint8_t>& bytes,
                                std::uint64_t epoch, std::size_t budget) {
    auto h = packet_wire::read(bytes, epoch, MessageType::InventoryRequest, budget);
    auto request = decode({bytes.begin() + packet_header_bytes, bytes.end()});
    require(request.operation != Operation::Fire, Error::InvalidRequest);
    return {h, std::move(request)};
}
}
