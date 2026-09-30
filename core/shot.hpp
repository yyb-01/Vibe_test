#pragma once
#include "fire_intent.hpp"
#include "ballistics.hpp"

namespace astra {
inline constexpr std::uint64_t fire_request_namespace = 0x53484f5446495245ULL;
struct ShotData {
    FireIntent intent;
    ballistics::Flight launch;
    std::int64_t massMg{};
    std::uint64_t effectiveQ16{};
    std::uint32_t ammoDef{}, visualSeed{};
    std::uint16_t durabilityCost{};
    bool operator==(const ShotData&) const = default;
};
struct RecordedFire { Id account, weapon; ShotData shot; std::uint64_t sequence{}, epoch{}; };
inline constexpr std::size_t shot_data_bytes = 108;
void validate_shot(const ShotData&);
std::vector<std::uint8_t> encode_shot(const ShotData&);
ShotData decode_shot(const std::vector<std::uint8_t>&);
}
