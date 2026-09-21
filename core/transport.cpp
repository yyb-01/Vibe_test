#include "transport.hpp"
#include "receipt.hpp"
#include "snapshot_control.hpp"
#include "wire.hpp"

namespace astra {
HostTransport::HostTransport(HostSession& host, const AuthenticatedPeer& peer,
                             const SessionInfo& handshake) : host_(host) {
    connection_ = host_.admit_authenticated(peer, handshake);
    try {
        PacketHeader h; h.worldEpoch = host_.info().epoch;
        h.messageType = MessageType::SessionResume;
        output_ = encode_stream(encode_resume(h, host_.resume_state(connection_)));
    } catch (...) { disconnect(); throw; }
}
HostTransport::~HostTransport() { disconnect(); }
std::uint64_t HostTransport::connection() const {
    host_.info(); return connection_;
}
std::span<const std::uint8_t> HostTransport::output() const {
    host_.info(); return std::span(output_).subspan(sent_);
}
void HostTransport::sent(std::size_t count) {
    require(count <= output().size(), Error::InvalidRequest);
    sent_ += count;
    if (sent_ == output_.size()) {
        output_.clear(); sent_ = 0;
        if (closing_) disconnect();
    }
}
std::size_t HostTransport::receive(std::span<const std::uint8_t> bytes,
                                   const InteractionState& observation) {
    host_.info(); require(connection_ != 0, Error::InvalidState);
    if (!output().empty()) return 0;
    try {
        auto consumed = input_.receive(bytes);
        if (input_.complete()) {
            auto payload = input_.take();
            Reader type{payload}; type.get(2);
            if (type.get(2) == static_cast<unsigned>(MessageType::SnapshotRequest)) {
                decode_snapshot_request(payload, host_.info().epoch);
                start_snapshot(observation); return consumed;
            }
            auto result = host_.receive(connection_, payload, observation);
            auto packet = decode_packet(payload, host_.info().epoch);
            PacketHeader h; h.worldEpoch = host_.info().epoch;
            h.messageType = MessageType::InventoryReceipt;
            output_ = encode_stream(encode_receipt(h,
                make_receipt(packet.request.id, result, h.worldEpoch)));
        }
        return consumed;
    } catch (...) { disconnect(); throw; }
}
void HostTransport::finish() {
    host_.info(); require(connection_ != 0, Error::InvalidState);
    try { input_.finish(); }
    catch (...) { disconnect(); throw; }
    disconnect();
}
void HostTransport::disconnect() {
    host_.info();
    if (connection_) host_.disconnect(connection_);
    connection_ = 0; output_.clear(); sent_ = 0;
    snapshot_.reset(); snapshot_output_.clear(); snapshot_sent_ = snapshot_page_ = 0;
    snapshot_offer_ = false;
}
}
