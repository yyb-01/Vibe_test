#include "session.hpp"

namespace astra {
void HostSession::publish_fire(const Result& result) {
    if (!result.applied()) return;
    const auto& w = *waitingFire_;
    const auto& shot = *w.request.shot;
    remember_fire({w.account, w.request.moves[1].item, shot, result.sequence}, w.admitted, true);
    if (result.sequence <= latestShot_) return;
    // Space was reserved before durable submission; owner-thread publication cannot allocate.
    flights_.push_back({{shot.launch, result.sequence, shot.massMg}, shot.effectiveQ16});
    latestShot_ = result.sequence;
}
std::vector<ShotImpact> HostSession::advance_combat(std::uint64_t now,
    const ballistics::Atmosphere& air, std::span<const ballistics::Barrier> scene,
    std::span<const ballistics::ApprovedReflection> rules) {
    owner(); require(!closing_, Error::Busy);
    require(!combatTime_ || now >= *combatTime_, Error::InvalidRequest);
    if (waitingFire_) {
        auto& w = *waitingFire_;
        if (!w.resolved) {
            auto result = inventory_.result_for(w.request, w.account);
            if (result && result->code != Error::Pending) w.resolved = result;
        }
        if (w.resolved) {
            require(w.resolved->code != Error::EpochMismatch && w.resolved->code != Error::InvalidState, w.resolved->code);
            publish_fire(*w.resolved);
        }
    }
    // ponytail: copy at most 512 flights for atomic publication; use jobs after real host profiling.
    auto next = advance_shots(flights_, now, air, scene, rules);
    flights_.swap(next.flights); combatTime_ = now;
    return std::move(next.impacts);
}
}
