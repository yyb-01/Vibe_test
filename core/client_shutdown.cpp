#include "client_state.hpp"
#include "shutdown.hpp"

namespace astra {
void ClientState::receive_shutdown(const std::vector<std::uint8_t>& bytes) {
    auto sequence = decode_shutdown(bytes, epoch_);
    require(sequence >= published_ && sequence >= confirmed_, Error::RevisionConflict);
    confirmed_ = sequence;
    disconnect(); // Retain original requests and final receipts for authenticated resume.
}
}
