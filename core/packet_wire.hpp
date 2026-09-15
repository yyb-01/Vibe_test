#pragma once
#include "packet.hpp"

namespace astra::packet_wire {
std::vector<std::uint8_t> wrap(PacketHeader, const std::vector<std::uint8_t>&,
                               MessageType expected, std::size_t budget);
PacketHeader read(const std::vector<std::uint8_t>&, std::uint64_t epoch,
                  MessageType expected, std::size_t budget);
}
