#include "client_transport.hpp"
#include "snapshot_control.hpp"

namespace astra {
void ClientTransport::request_snapshot(std::uint64_t token) {
    require(poll(token), Error::InvalidState); require(state_.connected(), Error::NotAccessible);
    require(output_.empty() && !snapshot_requested_, Error::Busy);
    auto wire = encode_stream(encode_snapshot_request(epoch_));
    state_.set_roots({}); lease_ = 0;
    snapshot_input_.emplace(); snapshot_requested_ = true; snapshot_offer_ = false;
    output_ = std::move(wire);
    deadlines_.begin(TransportDeadlines::Write); deadlines_.begin(TransportDeadlines::Snapshot);
}
std::uint64_t ClientTransport::snapshot_lease(std::uint64_t token) const {
    check(token); return lease_;
}
std::size_t ClientTransport::receive_snapshot(std::uint64_t token, std::span<const std::uint8_t> bytes) {
    require(poll(token), Error::InvalidState);
    try {
        require(state_.connected() && snapshot_requested_, Error::NotAccessible);
        auto consumed = snapshot_input_->receive(bytes);
        if (!snapshot_input_->complete()) return consumed;
        auto payload = snapshot_input_->take();
        if (!snapshot_offer_) {
            auto offer = decode_snapshot_offer(payload, epoch_);
            state_.set_roots(std::move(offer.roots)); state_.begin_snapshot(offer.descriptor);
            lease_ = offer.lease; snapshot_offer_ = true;
            snapshot_input_.emplace(snapshot_page_limit);
        } else if (state_.receive_page(payload)) {
            snapshot_requested_ = snapshot_offer_ = false; snapshot_input_.reset();
            deadlines_.end(TransportDeadlines::Snapshot);
        }
        return consumed;
    } catch (...) { disconnect(token); throw; }
}
void ClientTransport::finish_snapshot(std::uint64_t token) {
    check(token);
    try {
        if (snapshot_input_) snapshot_input_->finish();
        require(!snapshot_requested_, Error::InvalidRequest);
    } catch (...) { disconnect(token); throw; }
    disconnect(token);
}
}
