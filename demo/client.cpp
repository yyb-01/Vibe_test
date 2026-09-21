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
    : inventory_(inventory), host_(inventory, local_info(inventory.epoch()), {14, 9}),
      resume_({{host_.info().world, {77, 1}, host_.info().catalogHash}, inventory.epoch(), 0, 1}),
      client_(resume_, catalog()) { reconnect(); }
InteractionState ConsoleClient::observation() const {
    return {{14, 1}, true, true, {{id(10), 2.5, true, true},
                                 {id(20), 0, true, true}, {id(30), 1, true, true}}};
}
Result ConsoleClient::apply(const Request& request) {
    require(connected(), Error::NotAccessible);
    auto next = request;
    if (request_ && request_->id != request.id) {
        auto status = client_.state().status(request_->id).status;
        require(status == TransactionStatus::Committed || status == TransactionStatus::Rejected, Error::Busy);
    }
    client_.submit(token_, next);
    if (request_ && request_->id != next.id) client_.forget(request_->id);
    request_ = std::move(next);
    exchange(); return result();
}
Result ConsoleClient::retry() {
    require(connected(), Error::NotAccessible);
    require(request_.has_value(), Error::InvalidRequest);
    client_.retry(token_, request_->id); exchange(); return result();
}
