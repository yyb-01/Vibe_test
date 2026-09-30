#include "shot.hpp"
#include "wire.hpp"
#include "velocity_response.hpp"
#include <bit>

namespace astra {
void validate_shot(const ShotData& shot) {
    validate_fire_intent(shot.intent);
    require(shot.intent.buttons == trigger_on && shot.ammoDef && shot.durabilityCost, Error::InvalidRequest);
    ballistics::free_flight(shot.launch, {}, 1, 0);
    require(ballistics::velocity_energy(shot.launch.velocity, shot.massMg) > 0, Error::InvalidRequest);
}
std::vector<std::uint8_t> encode_shot(const ShotData& shot) {
    validate_shot(shot);
    Writer w; w.bytes = encode_fire_intent(shot.intent);
    for (auto vector : {shot.launch.position, shot.launch.velocity})
        for (auto axis : vector) w.put(static_cast<std::uint64_t>(axis), 8);
    w.put(static_cast<std::uint64_t>(shot.massMg), 8); w.put(shot.effectiveQ16, 8);
    w.put(shot.ammoDef, 4); w.put(shot.visualSeed, 4); w.put(shot.durabilityCost, 2);
    return std::move(w.bytes);
}
ShotData decode_shot(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size() == shot_data_bytes, Error::InvalidRequest);
    ShotData shot; shot.intent = decode_fire_intent({bytes.begin(), bytes.begin() + fire_intent_bytes});
    Reader r{bytes, fire_intent_bytes};
    for (auto* vector : {&shot.launch.position, &shot.launch.velocity})
        for (auto& axis : *vector) axis = std::bit_cast<std::int64_t>(r.get(8));
    shot.massMg = std::bit_cast<std::int64_t>(r.get(8)); shot.effectiveQ16 = r.get(8);
    shot.ammoDef = static_cast<std::uint32_t>(r.get(4)); shot.visualSeed = static_cast<std::uint32_t>(r.get(4));
    shot.durabilityCost = static_cast<std::uint16_t>(r.get(2));
    validate_shot(shot); return shot;
}
}
