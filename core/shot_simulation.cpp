#include "shot_simulation.hpp"
#include "error.hpp"
#include <algorithm>
#include <tuple>

namespace astra {
ShotStep advance_shots(std::span<const ShotFlight> input, std::uint64_t now,
    const ballistics::Atmosphere& air, std::span<const ballistics::Barrier> scene,
    std::span<const ballistics::ApprovedReflection> rules) {
    using namespace ballistics;
    require(input.size() <= max_active_shots, Error::LimitExceeded);
    curve_budget(air); first_barrier({}, {}, scene, 0);
    SurfaceKey previous{};
    for (auto rule : rules) {
        require(rule.surface.surface && rule.surface.collider && previous < rule.surface &&
            rule.gate && rule.gate->probabilityQ16 <= 65536, Error::InvalidRequest);
        if (!rule.energyResponse.empty()) sample_ricochet(rule.energyResponse, 0);
        previous = rule.surface;
    }
    ShotStep result;
    result.flights.reserve(max_active_shots); result.impacts.reserve(input.size() * 16);
    std::uint64_t previousId = 0;
    for (auto shot : input) {
        auto& p = shot.projectile;
        require(p.shotId > previousId && now >= shot.effectiveQ16, Error::InvalidRequest);
        previousId = p.shotId;
        auto target = std::min<std::uint64_t>((now - shot.effectiveQ16) / 16384, 1440);
        require(p.ageSubsteps <= target, Error::InvalidRequest);
        free_flight(p.flight, air, 1, 0);
        while (p.reason == StopReason::Flying && p.ageSubsteps < target) {
            auto start = shot.effectiveQ16 + std::uint64_t(p.ageSubsteps) * 16384;
            auto contacts = p.contacts;
            auto step = advance_reflections(p, air, scene, rules);
            for (std::uint32_t i = 0; i < step.count; ++i)
                result.impacts.push_back({step.impacts[i], start, static_cast<std::uint16_t>(contacts + i + 1)});
            p = step.state;
        }
        if (p.reason == StopReason::Flying) result.flights.push_back(shot);
    }
    auto order = [](const ShotImpact& event) {
        return std::tuple{event.substepQ16 + (event.impact.fraction >> 10),
            event.impact.fraction & 1023u, event.impact.shotId, event.contact};
    };
    std::sort(result.impacts.begin(), result.impacts.end(), [&](const auto& a, const auto& b) { return order(a) < order(b); });
    return result;
}
}
