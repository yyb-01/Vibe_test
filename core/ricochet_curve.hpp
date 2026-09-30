#pragma once
#include <cstdint>
#include <optional>
#include <span>

namespace astra::ballistics {
struct RicochetPoint {
    std::int64_t energyUj{};
    std::uint32_t probabilityQ16{};
    std::uint16_t keepUnorm{};
};
// Strictly increasing nonnegative energies. No extrapolation outside the calibrated domain.
// Interpolation order: low + Q((high-low)*(energy-lowEnergy)/width), nearest-even division.
std::optional<RicochetPoint> sample_ricochet(std::span<const RicochetPoint>, std::int64_t energyUj);
}
