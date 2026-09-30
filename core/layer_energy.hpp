#pragma once
#include "layer_paths.hpp"
#include "ballistic_energy.hpp"

namespace astra::ballistics {
struct LayerResistance { std::uint32_t layerId{}; Resistance material; };
struct LayerDeposit { LayerPath path; EnergyTransfer energy; };
struct LayerEnergyPlan { std::int64_t outgoingUj{}; std::vector<LayerDeposit> deposits; };
// Geometry/energy plan only: does not advance time or apply damage. No result until all paths are complete.
// Profiles are sorted by unique layerId. Each scene layer needs an authority-supplied profile, even on misses.
std::optional<LayerEnergyPlan> layer_energy(const Vector& from, const Vector& to,
    std::span<const LayerVolume>, std::span<const LayerResistance>, std::int64_t incomingUj);
}
