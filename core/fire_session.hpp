#pragma once
#include "fire_commit.hpp"
#include "packet.hpp"

namespace astra {
// Trusted owner-thread observations, like InteractionState; never decoded from the client's packet.
struct FireObservation {
    Id pawn, inventoryRoot, weapon, ammo;
    FireAuthority authority;
    ballistics::Flight launch;
    std::int64_t massMg{};
    std::uint32_t ammoDef{}, visualSeed{};
    std::uint16_t durabilityCost{};
};
struct FireResult {
    Result result;
    std::optional<ShotData> accepted; // Present only after durable success; repeats on replay.
};
// Server-internal result, not a client damage instruction. Effects must dedupe the world-local result.sequence.
struct FirePacket { PacketHeader header; FireIntent intent; };
std::vector<std::uint8_t> encode_fire_packet(PacketHeader, const FireIntent&, std::size_t budget = datagram_limit);
FirePacket decode_fire_packet(const std::vector<std::uint8_t>&, std::uint64_t epoch, std::size_t budget = datagram_limit);
}
