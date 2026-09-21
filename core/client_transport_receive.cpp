#include "client_transport.hpp"
#include "wire.hpp"

namespace astra {
std::size_t ClientTransport::receive(std::uint64_t token, std::span<const std::uint8_t> bytes) {
    require(poll(token), Error::InvalidState); // Stale callbacks cannot disconnect a new connection.
    try {
        if (!bytes.empty()) deadlines_.begin(TransportDeadlines::Read);
        auto consumed = input_->receive(bytes);
        if (!input_->complete()) return consumed;
        deadlines_.end(TransportDeadlines::Read);
        auto payload = input_->take();
        if (!state_.connected()) {
            state_.reconnect(decode_resume(payload, epoch_));
        } else {
            Reader reader{payload}; reader.get(2);
            auto type = static_cast<MessageType>(reader.get(2));
            if (type == MessageType::InventoryReceipt) state_.receive_receipt(payload);
            else if (type == MessageType::SessionClosing) {
                state_.receive_shutdown(payload); disconnect(token);
            } else throw Violation{Error::Incompatible};
        }
        return consumed;
    } catch (...) { disconnect(token); throw; }
}
}
