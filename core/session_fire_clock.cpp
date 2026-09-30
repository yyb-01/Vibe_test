#include "session.hpp"
#include <algorithm>

namespace astra {
void HostSession::remember_fire(const RecordedFire& record, TransactionBudget::Clock::time_point admitted,
                                bool currentClock) {
    auto& cursor = fireCursors_.at(record.account);
    if (record.sequence > cursor.shotId) {
        cursor = {record.sequence, record.shot.intent,
                  currentClock ? std::optional(record.shot.effectiveQ16) : std::nullopt};
    }
    auto& weapon = weaponClocks_.at(record.weapon);
    if (record.sequence > weapon.shotId) weapon = {record.sequence, admitted};
}
void HostSession::restore_fire_history() {
    auto started = now_();
    for (const auto& record : inventory_.recorded_fires()) {
        latestShot_ = std::max(latestShot_, record.sequence); // Historical shots never respawn on session startup.
        fireCursors_.try_emplace(record.account); weaponClocks_.try_emplace(record.weapon);
        // New epochs reset effective ticks; all recovered weapons wait one interval.
        remember_fire(record, started, record.epoch == info_.epoch);
    }
}
std::optional<FireResult> HostSession::settle_fire(Id account, const FireIntent& intent) {
    if (!waitingFire_) return {};
    auto& w = *waitingFire_;
    bool same = w.account == account && w.request.shot->intent.fireSeq == intent.fireSeq;
    if (same) require(w.request.shot->intent == intent, Error::IdempotencyMismatch);
    auto result = w.resolved ? w.resolved : inventory_.result_for(w.request, w.account);
    if (result && result->code == Error::Pending)
        return same ? std::optional(FireResult{*result, {}}) : std::nullopt;
    if (result) publish_fire(*result);
    if (result) require(result->code != Error::EpochMismatch && result->code != Error::InvalidState, result->code);
    auto reply = result && same ? std::optional(FireResult{*result, result->applied() ? w.request.shot : std::nullopt}) : std::nullopt;
    waitingFire_.reset(); // Missing means submission never reached prepare; definite abort also releases it.
    return reply;
}
void HostSession::check_fire_clock(Id account, Id weapon, const FireIntent& intent,
                                 const FireAuthority& authority, std::uint64_t effective) {
    auto cursor = fireCursors_.find(account);
    if (cursor != fireCursors_.end() && cursor->second.shotId) {
        const auto& c = cursor->second;
        require(serial_newer(intent.inputSeq, c.intent.inputSeq) && serial_newer(intent.fireSeq, c.intent.fireSeq) &&
                (!c.effective || effective > *c.effective), Error::SequenceMismatch);
    }
    auto found = weaponClocks_.find(weapon);
    if (found != weaponClocks_.end() && found->second.shotId) {
        auto time = now_(); require(time >= found->second.admitted, Error::InvalidState);
        constexpr std::uint64_t rate = 60 * 65536;
        auto period = std::chrono::nanoseconds((std::uint64_t(authority.minIntervalQ16) * 1000000000 + rate - 1) / rate);
        require(time - found->second.admitted >= period, Error::Busy);
    }
}
}
