#pragma once
#include "packet.hpp"
#include <array>

namespace astra {
struct ClientIdentity {
    Id world, account;
    std::array<std::uint8_t, 32> catalogHash{};
    bool operator==(const ClientIdentity&) const = default;
};
// Trusted control-plane result, delivered only after session authentication.
struct ResumeState {
    ClientIdentity identity;
    std::uint64_t epoch{}, sequence{}, nextActionSequence{};
};
// expectedEpoch comes from the authenticated handshake, never this packet.
std::vector<std::uint8_t> encode_resume(PacketHeader, const ResumeState&,
                                      std::size_t pathBudget = datagram_limit);
ResumeState decode_resume(const std::vector<std::uint8_t>&, std::uint64_t expectedEpoch,
                          std::size_t pathBudget = datagram_limit);
}
