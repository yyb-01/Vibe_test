#include "reconnect.hpp"
#include "packet_wire.hpp"
#include "wire.hpp"

namespace astra {
namespace {
void validate(const ResumeState& s) {
    require(bool(s.identity.world) && bool(s.identity.account), Error::InvalidRequest);
    require(s.epoch && s.epoch <= revision_limit, Error::EpochMismatch);
    require(s.sequence <= revision_limit && s.nextActionSequence &&
            s.nextActionSequence <= revision_limit, Error::InvalidRequest);
}
}
std::vector<std::uint8_t> encode_resume(PacketHeader h, const ResumeState& s, std::size_t budget) {
    validate(s);
    require(h.worldEpoch == s.epoch, Error::EpochMismatch);
    Writer w; w.bytes.reserve(80);
    w.id(s.identity.world); w.id(s.identity.account);
    for (auto byte : s.identity.catalogHash) w.put(byte, 1);
    w.put(s.sequence, 8); w.put(s.nextActionSequence, 8);
    return packet_wire::wrap(h, w.bytes, MessageType::SessionResume, budget);
}
ResumeState decode_resume(const std::vector<std::uint8_t>& bytes, std::uint64_t epoch, std::size_t budget) {
    auto h = packet_wire::read(bytes, epoch, MessageType::SessionResume, budget);
    require(h.payloadBytes == 80, Error::InvalidRequest);
    Reader r{bytes, packet_header_bytes}; ResumeState s;
    s.epoch = h.worldEpoch; s.identity.world = r.id(); s.identity.account = r.id();
    for (auto& byte : s.identity.catalogHash) byte = static_cast<std::uint8_t>(r.get(1));
    s.sequence = r.get(8); s.nextActionSequence = r.get(8);
    validate(s); return s;
}
}
