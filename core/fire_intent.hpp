#pragma once
#include "types.hpp"
#include <vector>

namespace astra {
inline constexpr std::uint8_t trigger_on = 1, trigger_off = 2;
struct FireIntent {
    std::uint32_t inputSeq{}, fireSeq{}, clientFireTick{};
    std::uint16_t subtick{};
    std::uint32_t weaponNetId{};
    std::uint16_t generation{};
    std::uint64_t assemblyRevision{};
    std::int16_t aimYaw{}, aimPitch{}; // 65536 units/turn; pitch restricted to +/-90 degrees.
    std::uint8_t buttons{}, approvedViewDelayFrames{};
    bool operator==(const FireIntent&) const = default;
};
inline constexpr std::size_t fire_intent_bytes = 34;
void validate_fire_intent(const FireIntent&);
std::vector<std::uint8_t> encode_fire_intent(const FireIntent&);
FireIntent decode_fire_intent(const std::vector<std::uint8_t>&);
}
