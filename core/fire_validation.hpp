#pragma once
#include "fire_intent.hpp"

namespace astra {
// Host-only snapshot. Never construct these authority fields from the intent payload.
struct FireAuthority {
    Id account, weaponOwner;
    std::uint32_t weaponNetId{};
    std::uint16_t generation{};
    std::uint64_t assemblyRevision{};
    std::int16_t aimYaw{}, aimPitch{};
    std::uint16_t maxYawError{}, maxPitchError{};
    bool alive{}, chambered{}, reloading{}, jammed{}, triggerReady{}, poseAvailable{}, muzzleClear{};
    bool local{}, clockReady{}, hasPrevious{};
    std::uint8_t approvedViewDelayFrames{};
    std::int32_t clientToServerTicks{}; // Bounded clock estimator's approved offset, not client advice.
    std::uint64_t nowQ16{}, lastAcceptedQ16{}, lastEffectiveQ16{}; // 60Hz ticks, unwrapped Q16.
    std::uint32_t minIntervalQ16{}, lastInputSeq{}, lastFireSeq{};
};
// Pure candidate check. Returns effective server fire time, not ShotAccepted.
// Caller must reserve/revalidate, persist ammo+durability+event atomically, then publish effects.
std::uint64_t validate_fire_candidate(const FireIntent&, const FireAuthority&);
}
