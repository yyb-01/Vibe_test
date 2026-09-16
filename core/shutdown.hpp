#pragma once
#include "packet.hpp"

namespace astra {
// Send only after HostSession::prepare_close succeeds, before closing the DB.
// This announces settled critical writes, not successful backup/DB close.
std::vector<std::uint8_t> encode_shutdown(PacketHeader, std::uint64_t sequence,
                                        std::size_t pathBudget = datagram_limit);
std::uint64_t decode_shutdown(const std::vector<std::uint8_t>&, std::uint64_t expectedEpoch,
                              std::size_t pathBudget = datagram_limit);
}
