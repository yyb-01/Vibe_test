#include "transport.hpp"
#include "snapshot_control.hpp"

namespace astra {
void HostTransport::start_snapshot(const InteractionState& observation) {
    require(!snapshot_ || snapshot_page_ == snapshot_pages(*snapshot_), Error::Busy);
    auto lease = host_.grant_lease(connection_, observation);
    auto descriptor = host_.start_snapshot(connection_, lease, observation);
    SnapshotOffer offer{lease, descriptor, interaction_roots(observation, observation.pawn)};
    snapshot_output_ = encode_stream(encode_snapshot_offer(offer));
    snapshot_ = descriptor; snapshot_page_ = snapshot_sent_ = 0; snapshot_offer_ = true;
}
std::span<const std::uint8_t> HostTransport::snapshot_output(const InteractionState& observation) {
    host_.info(); require(connection_ != 0, Error::InvalidState);
    if (!snapshot_ || closing_) return {};
    try {
        host_.validate_snapshot(connection_, snapshot_->id, observation);
        if (snapshot_output_.empty() && snapshot_page_ < snapshot_pages(*snapshot_))
            snapshot_output_ = encode_stream(host_.snapshot_page(connection_, snapshot_->id,
                                            snapshot_page_, observation), snapshot_page_limit);
        return std::span(snapshot_output_).subspan(snapshot_sent_);
    } catch (const Violation& e) {
        if (e.code != Error::Busy) disconnect(); // ponytail: revoke by disconnect; add a revocation message if needed.
        throw;
    } catch (...) { disconnect(); throw; }
}
void HostTransport::snapshot_sent(std::size_t count) {
    host_.info(); require(connection_ != 0, Error::InvalidState);
    require(count <= snapshot_output_.size() - snapshot_sent_, Error::InvalidRequest);
    snapshot_sent_ += count;
    if (!snapshot_output_.empty() && snapshot_sent_ == snapshot_output_.size()) {
        snapshot_output_.clear(); snapshot_sent_ = 0;
        if (snapshot_offer_) snapshot_offer_ = false;
        else ++snapshot_page_;
    }
}
}
