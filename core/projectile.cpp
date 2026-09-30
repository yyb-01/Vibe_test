#include "projectile.hpp"
#include "projectile_segment.hpp"
#include "ballistic_energy.hpp"
#include "velocity_response.hpp"
#include "fixed_math.hpp"
#include "error.hpp"

namespace astra::ballistics {
ProjectileStep advance_barriers(const Projectile& input, const Atmosphere& air, std::span<const Barrier> scene,
    std::uint32_t duration) {
    require(duration > 0 && duration <= (1u << 24) && input.contacts <= 16, Error::InvalidRequest);
    require(input.shotId && input.radiusUm >= 0 && input.radiusUm <= 100000 && input.ageSubsteps <= 1440 &&
            input.distanceUpperUm >= 0 && input.distanceUpperUm <= 2500000000LL,
            Error::InvalidRequest);
    kinetic_energy(input.massMg, 0);
    require(input.reason >= StopReason::Flying && input.reason <= StopReason::Limit, Error::InvalidRequest);
    ProjectileStep result{input, {}};
    if (input.reason != StopReason::Flying) return result;
    if (input.contacts == 16) {
        result.state.reason = StopReason::Limit; result.state.flight.velocity = {}; return result;
    }
    if (input.ageSubsteps == 1440) { result.state.reason = StopReason::Expired; return result; }
    if (input.distanceUpperUm == 2500000000LL) { result.state.reason = StopReason::Range; return result; }
    auto budget = curve_budget(air);
    constexpr std::int64_t one = 1 << 24;
    for (std::uint32_t part = 0; part < budget.divisions; ++part) {
        auto before = result.state.flight;
        Flight next;
        try { next = free_flight(before, air, budget.divisions, duration); }
        catch (const Violation& error) {
            if (error.code != Error::LimitExceeded) throw;
            result.state.reason = StopReason::Limit; result.state.flight.velocity = {};
            return result;
        }
        auto distance = detail::distance_bound(before, next, budget.marginUm);
        auto remaining = 2500000000LL - result.state.distanceUpperUm;
        bool range = distance >= remaining;
        auto fraction = static_cast<std::uint32_t>(range ? remaining * one / distance : one);
        auto hit = first_barrier(before.position, next.position, scene, input.radiusUm + budget.marginUm);
        if (hit && hit->contact.fraction > fraction) hit.reset();
        if (hit) fraction = hit->contact.fraction;
        result.state.distanceUpperUm += (distance * fraction + one - 1) / one;
        if (hit || range) {
            next = detail::blend(before, next, fraction);
            auto energy = velocity_energy(next.velocity, input.massMg);
            auto incoming = next.velocity;
            next.velocity = {}; result.state.flight = next;
            result.state.reason = hit ? StopReason::Barrier : StopReason::Range;
            auto time = static_cast<std::uint32_t>(fixed::mul_div(part * one + fraction, 1, budget.divisions));
            if (hit) result.impact = BarrierImpact{input.shotId, hit->key, next.position, energy, time, incoming, hit->contact.normal};
            return result;
        }
        result.state.flight = next;
    }
    if (++result.state.ageSubsteps == 1440) result.state.reason = StopReason::Expired;
    return result;
}
}
