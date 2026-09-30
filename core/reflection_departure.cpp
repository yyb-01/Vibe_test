#include "reflection_loop.hpp"
#include "velocity_response.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics::detail {
void leave_reflection(ReflectionStep& result, const BarrierImpact& impact,
    std::span<const Barrier> scene, std::int64_t margin) {
    auto& state = result.state;
    auto wall = std::find_if(scene.begin(), scene.end(), [&](auto b) { return b.key == impact.surface; });
    require(wall != scene.end(), Error::InvalidState);
    auto from = state.flight.position;
    for (std::size_t i = 0; i < 3; ++i) {
        if (impact.normal[i] < 0) from[i] = std::max(-8000000000LL, wall->box.min[i] - margin);
        if (impact.normal[i] > 0) from[i] = std::min(8000000000LL, wall->box.max[i] + margin);
    }
    auto to = from;
    std::int64_t distance = 100;
    for (std::size_t i = 0; i < 3; ++i) {
        distance += std::abs(from[i] - state.flight.position[i]);
        to[i] += 100 * impact.normal[i];
        if (to[i] < -8000000000LL || to[i] > 8000000000LL) {
            state.reason = StopReason::Limit; state.flight.velocity = {}; return;
        }
    }
    if (distance > 2500000000LL - state.distanceUpperUm) {
        state.reason = StopReason::Range; state.flight.velocity = {}; return;
    }
    auto hit = first_barrier(from, to, scene, margin, impact.surface);
    if (hit) {
        for (std::size_t i = 0; i < 3; ++i)
            to[i] = from[i] + fixed::mul_div(to[i] - from[i], hit->contact.fraction, 1 << 24);
        auto energy = velocity_energy(state.flight.velocity, state.massMg);
        result.impacts[result.count++] = {state.shotId, hit->key, to, energy, impact.fraction,
            state.flight.velocity, hit->contact.normal};
        ++state.contacts;
        state.reason = state.contacts == 16 || result.count == 8 ? StopReason::Limit : StopReason::Barrier;
        state.flight.velocity = {};
    }
    state.distanceUpperUm += distance; state.flight.position = to;
}
}
