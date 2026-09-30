#pragma once
#include "velocity_response.hpp"
#include <optional>

namespace astra::ballistics {
struct PenetrationTransit {
    Vector entryVelocity{}, exitVelocity{};
    EnergyTransfer energy;
    // Q0.24 units of a 1/240s substep; may span multiple substeps. Unset means no exit.
    std::optional<std::int64_t> duration;
};
// Straight, constant material resistance. Entry loss precedes travel; no air/gravity inside.
// A timing plan only: does not teleport to an exit or apply damage before elapsed time.
PenetrationTransit penetration_transit(const Vector&, std::int64_t massMg,
    std::int64_t actualPathUm, const Resistance&);
}
