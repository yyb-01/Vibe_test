#include "check.hpp"
#include "fire_validation.hpp"

void fire_validation() {
    using namespace astra;
    constexpr std::uint64_t frame = 65536;
    FireIntent intent{11, 21, 95, 0, 7, 2, 3, 100, -100, trigger_on, 2};
    FireAuthority state;
    state.account = state.weaponOwner = {1, 2}; state.weaponNetId = 7; state.generation = 2;
    state.assemblyRevision = 3; state.aimYaw = 100; state.aimPitch = -100;
    state.maxYawError = state.maxPitchError = 20;
    state.alive = state.chambered = state.triggerReady = state.poseAvailable = state.muzzleClear = true;
    state.clockReady = state.hasPrevious = true; state.approvedViewDelayFrames = 2;
    state.nowQ16 = 100 * frame; state.lastAcceptedQ16 = 90 * frame; state.lastEffectiveQ16 = 89 * frame;
    state.minIntervalQ16 = 6 * frame; state.lastInputSeq = 10; state.lastFireSeq = 20;
    CHECK(validate_fire_candidate(intent, state) == 95 * frame);
    auto bad = intent; bad.fireSeq = 20;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::SequenceMismatch);
    bad = intent; bad.assemblyRevision = 4;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::RevisionConflict);
    bad = intent; bad.generation = 3;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::NotAccessible);
    bad = intent; bad.approvedViewDelayFrames = 1;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::NotAccessible);
    bad = intent; bad.aimYaw = 121;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::NotAccessible);
    for (auto gate : {&FireAuthority::alive, &FireAuthority::chambered, &FireAuthority::triggerReady,
            &FireAuthority::poseAvailable, &FireAuthority::muzzleClear, &FireAuthority::clockReady}) {
        auto denied = state; denied.*gate = false;
        rejects([&] { validate_fire_candidate(intent, denied); }, Error::NotAccessible);
    }
    auto busy = state; busy.lastAcceptedQ16 = 99 * frame;
    rejects([&] { validate_fire_candidate(intent, busy); }, Error::Busy);
    auto denied = state; denied.weaponOwner = {9, 9};
    rejects([&] { validate_fire_candidate(intent, denied); }, Error::NotAccessible);
    for (auto gate : {&FireAuthority::reloading, &FireAuthority::jammed}) {
        denied = state; denied.*gate = true;
        rejects([&] { validate_fire_candidate(intent, denied); }, Error::NotAccessible);
    }
    bad = intent; bad.inputSeq = state.lastInputSeq;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::SequenceMismatch);
    denied = state; denied.lastEffectiveQ16 = denied.lastAcceptedQ16 = 96 * frame;
    rejects([&] { validate_fire_candidate(intent, denied); }, Error::SequenceMismatch);
    bad = intent; bad.clientFireTick = 90;
    CHECK(validate_fire_candidate(bad, state) == 90 * frame);
    bad.clientFireTick = 89; bad.subtick = 65535;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::InvalidRequest);
    bad.clientFireTick = 100; bad.subtick = 1;
    rejects([&] { validate_fire_candidate(bad, state); }, Error::InvalidRequest);
    auto local = state; local.local = true; local.clockReady = false; local.clientToServerTicks = INT32_MAX;
    CHECK(validate_fire_candidate(bad, local) == state.nowQ16);
    auto shifted = state; shifted.clientToServerTicks = -20;
    bad = intent; bad.clientFireTick = 115;
    CHECK(validate_fire_candidate(bad, shifted) == 95 * frame);
    auto wrapped = state; wrapped.hasPrevious = false; wrapped.nowQ16 = ((std::uint64_t{1} << 32) + 2) * frame;
    bad = intent; bad.clientFireTick = UINT32_MAX;
    CHECK(validate_fire_candidate(bad, wrapped) == std::uint64_t(UINT32_MAX) * frame);
    wrapped = state; wrapped.lastInputSeq = wrapped.lastFireSeq = UINT32_MAX;
    bad = intent; bad.inputSeq = bad.fireSeq = 0;
    CHECK(validate_fire_candidate(bad, wrapped) == 95 * frame);
    wrapped = state; wrapped.aimYaw = 32760;
    bad = intent; bad.aimYaw = -32760;
    CHECK(validate_fire_candidate(bad, wrapped) == 95 * frame);
    CHECK(state.lastFireSeq == 20 && state.lastAcceptedQ16 == 90 * frame);
}
