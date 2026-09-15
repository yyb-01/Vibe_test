#include "client.hpp"

namespace {
SessionInfo local_info(std::uint64_t epoch) {
    SessionInfo info;
    info.session = {epoch, 1}; info.world = {1, 1}; info.host = {77, 9};
    info.identity = IdentityKind::LocalLan;
    return info; // Fixture IDs/catalog shared in-process; no service handshake is claimed.
}
}
ConsoleClient::ConsoleClient(DurableInventory& inventory)
    : host_(inventory, local_info(inventory.epoch()), {14, 9}),
      connection_(host_.admit_authenticated({{77, 1}, {14, 1}, IdentityKind::LocalLan}, host_.info())),
      resume_(read_resume()), client_(resume_, catalog()) {}
InteractionState ConsoleClient::observation() const {
    return {{14, 1}, true, true, {{id(10), 2.5, true, true},
                                 {id(20), 0, true, true}, {id(30), 1, true, true}}};
}
Result ConsoleClient::apply(const Request& request) {
    auto next = request;
    if (request_ && request_->id != request.id) {
        auto status = client_.status(request_->id).status;
        require(status == TransactionStatus::Committed || status == TransactionStatus::Rejected, Error::Busy);
    }
    client_.track(next);
    if (request_ && request_->id != next.id) client_.forget(request_->id);
    request_ = std::move(next);
    return retry();
}
Result ConsoleClient::retry() {
    require(client_.connected(), Error::NotAccessible);
    require(request_.has_value(), Error::InvalidRequest);
    PacketHeader header; header.worldEpoch = host_.info().epoch; header.sequence = sequence_++;
    auto request = decode(client_.retry_payload(request_->id));
    auto result = host_.receive(connection_, encode_packet(header, request), observation());
    header.messageType = MessageType::InventoryReceipt;
    auto receipt = make_receipt(request.id, result, header.worldEpoch);
    bool changed = client_.receive_receipt(encode_receipt(header, receipt));
    auto status = client_.status(request.id).status;
    if (status == TransactionStatus::Pending || status == TransactionStatus::Resolving)
        return {Error::Pending, 0, {}};
    // Keep the host diagnostic (including created ID); the client view uses only wire data.
    if (changed) final_ = result;
    return final_;
}
