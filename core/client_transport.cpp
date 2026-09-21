#include "client_transport.hpp"

namespace astra {
ClientTransport::ClientTransport(const ResumeState& baseline, Catalog catalog)
    : state_(baseline, std::move(catalog)), epoch_(baseline.epoch) {
    state_.disconnect();
}
void ClientTransport::owner() const {
    require(std::this_thread::get_id() == owner_, Error::InvalidState);
}
void ClientTransport::check(std::uint64_t token) const {
    owner(); require(active_ && token == generation_, Error::InvalidState);
}
const ClientState& ClientTransport::state() const { owner(); return state_; }
std::uint64_t ClientTransport::open_authenticated(std::uint64_t epoch) {
    owner(); require(!active_ && generation_ < UINT64_MAX, Error::InvalidState);
    require(epoch >= epoch_ && epoch <= revision_limit, Error::EpochMismatch);
    input_.emplace(); epoch_ = epoch; active_ = true;
    return ++generation_;
}
void ClientTransport::disconnect(std::uint64_t token) {
    owner();
    if (!active_ || token != generation_) return;
    active_ = false; state_.disconnect(); input_.reset();
    output_.clear(); sent_ = 0;
    snapshot_input_.reset(); lease_ = 0; snapshot_requested_ = snapshot_offer_ = false;
}
void ClientTransport::finish(std::uint64_t token) {
    check(token);
    try { input_->finish(); }
    catch (...) { disconnect(token); throw; }
    disconnect(token);
}
void ClientTransport::submit(std::uint64_t token, const Request& request) {
    check(token); require(state_.connected(), Error::NotAccessible);
    require(output_.empty(), Error::Busy);
    PacketHeader h; h.worldEpoch = epoch_;
    auto wire = encode_stream(encode_packet(h, request));
    state_.track(request); output_ = std::move(wire);
}
void ClientTransport::retry(std::uint64_t token, Id id) {
    check(token); submit(token, decode(state_.retry_payload(id)));
}
void ClientTransport::forget(Id id) { owner(); state_.forget(id); }
void ClientTransport::timeout(std::uint64_t token, Id id) { check(token); state_.timeout(id); }
std::span<const std::uint8_t> ClientTransport::output(std::uint64_t token) const {
    check(token); return std::span(output_).subspan(sent_);
}
void ClientTransport::sent(std::uint64_t token, std::size_t count) {
    require(count <= output(token).size(), Error::InvalidRequest);
    sent_ += count;
    if (sent_ == output_.size()) { output_.clear(); sent_ = 0; }
}
}
