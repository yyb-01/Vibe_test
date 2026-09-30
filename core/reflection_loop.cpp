#include "reflection_loop.hpp"
#include "velocity_response.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics {
ReflectionStep advance_reflections(const Projectile& input, const Atmosphere& air, std::span<const Barrier> scene,
    std::span<const ApprovedReflection> approvals, std::uint32_t duration, std::uint32_t contactBudget) {
    require(duration > 0 && duration <= (1u << 24) && contactBudget > 0 && contactBudget <= 8, Error::InvalidRequest);
    SurfaceKey previous{};
    for (auto rule : approvals) {
        require(rule.surface.surface && rule.surface.collider && previous < rule.surface, Error::InvalidRequest);
        require(!rule.gate || rule.gate->probabilityQ16 <= 65536, Error::InvalidRequest);
        if (!rule.energyResponse.empty()) {
            require(rule.gate.has_value(), Error::InvalidRequest);
            sample_ricochet(rule.energyResponse, 0); // Validate all profiles even on a miss.
        }
        previous = rule.surface;
    }
    ReflectionStep result{input};
    constexpr std::uint32_t one = 1u << 24;
    std::uint32_t remaining = duration; // Tail of the current substep; timestamps remain substep-relative.
    for (;;) {
        auto step = advance_barriers(result.state, air, scene, remaining);
        result.state = step.state;
        if (!step.impact) return result;
        auto impact = *step.impact;
        auto consumed = static_cast<std::uint32_t>(fixed::mul_div(remaining, impact.fraction, one));
        remaining -= consumed; impact.fraction = one - remaining;
        auto& event = result.impacts[result.count++]; event = impact;
        if (result.state.contacts < 16) ++result.state.contacts;
        if (result.count == contactBudget || result.state.contacts == 16) {
            result.state.reason = StopReason::Limit; return result;
        }
        auto rule = std::find_if(approvals.begin(), approvals.end(), [&](auto r) { return r.surface == impact.surface; });
        std::int64_t dot = 0;
        for (std::size_t i = 0; i < 3; ++i) dot += impact.incomingVelocity[i] * impact.normal[i];
        if (rule == approvals.end() || dot >= 0) return result;
        auto gate = rule->gate; auto keep = rule->keep;
        if (!rule->energyResponse.empty()) {
            auto sample = sample_ricochet(rule->energyResponse, impact.depositedUj);
            if (!sample) return result;
            gate->probabilityQ16 = sample->probabilityQ16; keep = sample->keepUnorm;
        }
        if (gate && !approve_ricochet(impact, input.massMg, result.state.contacts, *gate)) return result;
        auto response = reflect_axis(impact.incomingVelocity, input.massMg, impact.normal, keep);
        event.depositedUj = response.energy.depositedUj;
        result.state.flight.velocity = response.velocity;
        if (!response.energy.outgoingUj) return result;
        result.state.reason = StopReason::Flying;
        detail::leave_reflection(result, impact, scene, input.radiusUm + curve_budget(air).marginUm);
        if (result.state.reason != StopReason::Flying) return result;
        if (!remaining) {
            if (++result.state.ageSubsteps == 1440) result.state.reason = StopReason::Expired;
            return result;
        }
    }
}
}
