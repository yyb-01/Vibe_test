#pragma once
#include "penetration_transit.hpp"

namespace astra::ballistics {
struct TransitProgress {
    Vector velocity;
    std::int64_t travelledUm{}, absorbedUj{}; // Cumulative, includes entry loss at elapsed=0.
    bool exited{};
    bool operator==(const TransitProgress&) const = default;
};
// Absolute elapsed Q0.24 substep time, in [0, plan.duration]. Requires a successful exit plan.
// Apply absorbedUj differences once; this pure sampler does not emit damage/events.
TransitProgress transit_progress(const PenetrationTransit&, std::int64_t massMg,
    std::int64_t actualPathUm, std::int64_t elapsed);
}
