#include "client_transport.hpp"
#include "wire.hpp"

namespace astra {
std::size_t ClientTransport::receive(std::uint64_t token, std::span<const std::uint8_t> bytes) {
    check(token); // Reject stale callbacks before the failure handler can disconnect us.
    try {
        auto consumed = input_->receive(bytes);
        if (!input_->complete()) return consumed;
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
