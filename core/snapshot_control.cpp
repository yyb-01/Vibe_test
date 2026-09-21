#include "snapshot_control.hpp"
#include "packet_wire.hpp"
#include "wire.hpp"

namespace astra {
namespace {
void validate_offer(const SnapshotOffer& offer) {
    const auto& d = offer.descriptor; (void)snapshot_pages(d);
    require(offer.lease && offer.lease <= revision_limit && d.id.hi == d.epoch && d.id.lo &&
            !offer.roots.empty() && offer.roots.size() <= 16 && !offer.roots.contains(Id{}),
            Error::InvalidRequest);
}
}
std::vector<std::uint8_t> encode_snapshot_request(std::uint64_t epoch) {
    PacketHeader h; h.worldEpoch = epoch; h.messageType = MessageType::SnapshotRequest;
    return packet_wire::wrap(h, {}, h.messageType, datagram_limit);
}
void decode_snapshot_request(const std::vector<std::uint8_t>& bytes, std::uint64_t epoch) {
    auto h = packet_wire::read(bytes, epoch, MessageType::SnapshotRequest, datagram_limit);
    require(!h.payloadBytes, Error::InvalidRequest);
}
std::vector<std::uint8_t> encode_snapshot_offer(const SnapshotOffer& offer) {
    validate_offer(offer); const auto& d = offer.descriptor;
    Writer w; w.put(offer.lease, 8); w.id(d.id); w.put(d.sequence, 8); w.put(d.bytes, 4);
    w.put(offer.roots.size(), 2); for (auto root : offer.roots) w.id(root);
    PacketHeader h; h.worldEpoch = d.epoch; h.messageType = MessageType::SnapshotOffer;
    return packet_wire::wrap(h, w.bytes, h.messageType, datagram_limit);
}
SnapshotOffer decode_snapshot_offer(const std::vector<std::uint8_t>& bytes, std::uint64_t epoch) {
    auto h = packet_wire::read(bytes, epoch, MessageType::SnapshotOffer, datagram_limit);
    require(h.payloadBytes >= 38, Error::InvalidRequest);
    Reader r{bytes, packet_header_bytes}; SnapshotOffer offer;
    offer.lease = r.get(8); offer.descriptor.id = r.id(); offer.descriptor.epoch = epoch;
    offer.descriptor.sequence = r.get(8); offer.descriptor.bytes = r.get(4);
    auto count = r.get(2);
    require(count && count <= 16 && h.payloadBytes == 38 + 16 * count, Error::InvalidRequest);
    for (std::size_t n = 0; n < count; ++n)
        require(offer.roots.insert(r.id()).second, Error::InvalidRequest);
    validate_offer(offer); return offer;
}
}
