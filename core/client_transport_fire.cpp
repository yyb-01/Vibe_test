#include "client_transport.hpp"

namespace astra {
void ClientTransport::submit_fire(std::uint64_t token, const FireIntent& intent) {
    require(poll(token), Error::InvalidState); require(state_.connected(), Error::NotAccessible);
    require(output_.empty(), Error::Busy);
    PacketHeader h; h.worldEpoch = epoch_; h.messageType = MessageType::FireIntent;
    auto wire = encode_stream(encode_fire_packet(h, intent));
    state_.track_fire(intent); output_ = std::move(wire);
    deadlines_.begin(TransportDeadlines::Write);
}
void ClientTransport::retry_fire(std::uint64_t token, std::uint32_t seq) {
    check(token); submit_fire(token, state_.retry_fire(seq));
}
void ClientTransport::forget_fire(std::uint32_t seq) { owner(); state_.forget_fire(seq); }
void ClientTransport::timeout_fire(std::uint64_t token, std::uint32_t seq) { check(token); state_.timeout_fire(seq); }
}
