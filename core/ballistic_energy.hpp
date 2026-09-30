#pragma once
#include <cstdint>

namespace astra::ballistics {
struct Resistance {
    std::int64_t entryUj{}, resistanceUjPerUm{}, minPathUm{1}, maxPathUm{1};
};
struct EnergyTransfer {
    std::int64_t outgoingUj{}, depositedUj{};
};
// Calibration data is supplied by the authority, never inferred from a material name.
std::int64_t kinetic_energy(std::int64_t massMg, std::int64_t speedUmPerSecond);
EnergyTransfer penetrate(std::int64_t incomingUj, std::int64_t actualPathUm, const Resistance&);
EnergyTransfer ricochet_energy(std::int64_t incomingUj, std::uint16_t keepUnorm);
struct Deposit { std::int64_t surfaceUj{}, bodyUj{}, fragmentsUj{}; };
// Apply only when collision establishes an actual body path. Fractions share one deposit.
Deposit split_deposit(std::int64_t depositedUj, std::uint16_t bluntUnorm, std::uint16_t spallUnorm);
}
