#include "fire_validation.hpp"
#include "packet.hpp"
#include <cstdlib>

namespace astra {
std::uint64_t validate_fire_candidate(const FireIntent& intent, const FireAuthority& state) {
    validate_fire_intent(intent);
    require(state.minIntervalQ16 && state.maxYawError <= 32768 && state.maxPitchError <= 32768 &&
        state.aimPitch >= -16384 && state.aimPitch <= 16384 && state.approvedViewDelayFrames <= 12,
        Error::InvalidState);
    require(intent.buttons == trigger_on, Error::InvalidRequest);
    require(bool(state.account) && state.account == state.weaponOwner && intent.weaponNetId == state.weaponNetId &&
        intent.generation == state.generation, Error::NotAccessible);
    require(intent.assemblyRevision == state.assemblyRevision, Error::RevisionConflict);
    require(state.alive && state.chambered && !state.reloading && !state.jammed && state.triggerReady &&
        state.poseAvailable && state.muzzleClear, Error::NotAccessible);
    require(intent.approvedViewDelayFrames == state.approvedViewDelayFrames, Error::NotAccessible);
    auto yaw = std::int32_t(intent.aimYaw) - state.aimYaw;
    if (yaw > 32767) yaw -= 65536;
    if (yaw < -32768) yaw += 65536;
    require(std::abs(yaw) <= state.maxYawError &&
        std::abs(std::int32_t(intent.aimPitch) - state.aimPitch) <= state.maxPitchError, Error::NotAccessible);
    std::uint64_t age = 0;
    if (!state.local) {
        require(state.clockReady, Error::NotAccessible);
        auto mapped = intent.clientFireTick + static_cast<std::uint32_t>(state.clientToServerTicks);
        auto ticks = static_cast<std::uint32_t>(state.nowQ16 >> 16) - mapped;
        require(ticks < 0x80000000u, Error::InvalidRequest);
        auto difference = std::int64_t(ticks) * 65536 + std::int64_t(state.nowQ16 & 65535) - intent.subtick;
        require(difference >= 0, Error::InvalidRequest);
        age = static_cast<std::uint64_t>(difference);
    }
    require(age <= state.nowQ16 && age + std::uint64_t(state.approvedViewDelayFrames) * 65536 <= 12 * 65536,
        Error::InvalidRequest);
    auto effective = state.nowQ16 - age;
    if (state.hasPrevious) {
        require(state.lastEffectiveQ16 <= state.lastAcceptedQ16 && state.lastAcceptedQ16 <= state.nowQ16,
            Error::InvalidState);
        require(serial_newer(intent.inputSeq, state.lastInputSeq) && serial_newer(intent.fireSeq, state.lastFireSeq) &&
            effective > state.lastEffectiveQ16, Error::SequenceMismatch);
        require(state.nowQ16 - state.lastAcceptedQ16 >= state.minIntervalQ16, Error::Busy);
    }
    return effective;
}
}
