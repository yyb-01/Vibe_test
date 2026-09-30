#include "fire_intent.hpp"
#include "wire.hpp"
#include <bit>

namespace astra {
void validate_fire_intent(const FireIntent& intent) {
    require(intent.weaponNetId && intent.assemblyRevision && intent.assemblyRevision <= revision_limit &&
        intent.aimPitch >= -16384 && intent.aimPitch <= 16384 &&
        (intent.buttons == trigger_on || intent.buttons == trigger_off) &&
        intent.approvedViewDelayFrames <= 12, Error::InvalidRequest);
}
std::vector<std::uint8_t> encode_fire_intent(const FireIntent& intent) {
    validate_fire_intent(intent);
    Writer w; w.bytes.reserve(fire_intent_bytes);
    for (auto n : {intent.inputSeq, intent.fireSeq, intent.clientFireTick}) w.put(n, 4);
    w.put(intent.subtick, 2); w.put(intent.weaponNetId, 4); w.put(intent.generation, 2);
    w.put(intent.assemblyRevision, 8);
    w.put(static_cast<std::uint16_t>(intent.aimYaw), 2);
    w.put(static_cast<std::uint16_t>(intent.aimPitch), 2);
    w.put(intent.buttons, 1); w.put(intent.approvedViewDelayFrames, 1);
    return std::move(w.bytes);
}
FireIntent decode_fire_intent(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size() == fire_intent_bytes, Error::InvalidRequest);
    Reader r{bytes}; FireIntent intent;
    intent.inputSeq = static_cast<std::uint32_t>(r.get(4));
    intent.fireSeq = static_cast<std::uint32_t>(r.get(4));
    intent.clientFireTick = static_cast<std::uint32_t>(r.get(4));
    intent.subtick = static_cast<std::uint16_t>(r.get(2));
    intent.weaponNetId = static_cast<std::uint32_t>(r.get(4));
    intent.generation = static_cast<std::uint16_t>(r.get(2)); intent.assemblyRevision = r.get(8);
    intent.aimYaw = std::bit_cast<std::int16_t>(static_cast<std::uint16_t>(r.get(2)));
    intent.aimPitch = std::bit_cast<std::int16_t>(static_cast<std::uint16_t>(r.get(2)));
    intent.buttons = static_cast<std::uint8_t>(r.get(1));
    intent.approvedViewDelayFrames = static_cast<std::uint8_t>(r.get(1));
    validate_fire_intent(intent);
    return intent;
}
}
