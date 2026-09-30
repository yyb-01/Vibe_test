#include "volume_projectile.hpp"
#include "error.hpp"

namespace astra::ballistics {
VolumeProjectileStep advance_volume_projectile(const VolumeProjectile& input, std::uint32_t duration) {
    constexpr std::uint32_t one = 1u << 24;
    constexpr std::int64_t range = 2500000000LL;
    const auto& p = input.projectile;
    require(p.shotId && p.radiusUm == 0 && p.ageSubsteps <= 1440 && p.contacts <= 16 &&
        p.distanceUpperUm >= 0 && p.distanceUpperUm <= range && input.distanceAtEntry >= 0 &&
        input.distanceAtEntry <= range && input.substepFraction < one && duration <= one &&
        p.reason >= StopReason::Flying && p.reason <= StopReason::Limit, Error::InvalidRequest);
    kinetic_energy(p.massMg, 0);
    VolumeProjectileStep result{input, 0, 0, duration, false};
    auto& out = result.state.projectile;
    auto stop = [&](StopReason why) { out.reason = why; out.flight.velocity = {}; };
    if (p.reason != StopReason::Flying) return result;
    require(duration <= one - input.substepFraction, Error::InvalidRequest);
    if (p.ageSubsteps == 1440) { stop(StopReason::Expired); return result; }
    if (p.contacts == 16) { stop(StopReason::Limit); return result; }
    require(p.massMg == input.transit.massMg && p.flight == input.transit.flight &&
        input.transit.pathUm <= 27712812922LL, Error::InvalidRequest);
    advance_volume(input.transit, 0); // Validate the stored flight/energy against the plan.
    auto distance = [&](const VolumeTransit& state) {
        auto progress = transit_progress(state.plan, state.massMg, state.pathUm, state.elapsed);
        // One cumulative allowance for endpoint/path rounding, independent of call partitioning.
        return input.distanceAtEntry + progress.travelledUm + (state.elapsed ? 4 : 0);
    };
    require(p.distanceUpperUm == distance(input.transit), Error::InvalidRequest);
    if (p.distanceUpperUm == range) { stop(StopReason::Range); return result; }
    auto step = advance_volume(input.transit, duration);
    bool limited = distance(step.state) > range;
    if (limited) {
        std::uint32_t low = 0, high = step.consumed;
        while (high - low > 1) {
            auto mid = low + (high - low) / 2;
            if (distance(advance_volume(input.transit, mid).state) <= range) low = mid; else high = mid;
        }
        step = advance_volume(input.transit, low);
    }
    result.state.transit = step.state; out.flight = step.state.flight;
    out.distanceUpperUm = distance(step.state);
    result.absorbedDeltaUj = step.absorbedDeltaUj;
    result.consumed = step.consumed; result.remaining = duration - step.consumed; result.exited = step.exited;
    result.state.substepFraction += step.consumed;
    if (result.state.substepFraction == one) { result.state.substepFraction = 0; ++out.ageSubsteps; }
    if (limited || out.distanceUpperUm == range) stop(StopReason::Range);
    else if (out.ageSubsteps == 1440) stop(StopReason::Expired);
    return result;
}
}
