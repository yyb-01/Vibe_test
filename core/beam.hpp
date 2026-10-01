#pragma once
#include "layer_energy.hpp"
#include "survival.hpp"
namespace astra {
struct BeamTarget {
    Id entity,armor;std::uint32_t epoch{};std::uint8_t kind{},region{};
    std::uint16_t contact{};bool vital{},entering{};
    ballistics::Resistance material;double u{.5},v{.5};
};
struct BeamLayer {ballistics::LayerVolume volume;BeamTarget target;};
struct BeamSlice {ballistics::Vector entry{},exit{};std::vector<BeamTarget> active;};
struct BeamMotion {
    ballistics::Vector entry{},exit{},startVelocity{},endVelocity{};
    std::int64_t pathUm{},duration{},elapsed{},entryUj{},endUj{},absorbedUj{};
    std::array<std::int64_t,16> distributed{};bool vitalEmitted{};
};
struct BeamTransit {std::vector<BeamSlice> slices;std::uint32_t index{};std::optional<BeamMotion> motion;};
struct BeamDeposit {BeamTarget target;std::int64_t energyUj{};};
struct BeamStep {std::uint32_t remaining{};bool exited{},stopped{};std::vector<BeamDeposit> deposits;};
BeamTransit start_beam(const ballistics::Flight&,std::span<const BeamLayer>,std::uint16_t& contacts);
BeamStep advance_beam(BeamTransit&,ballistics::Flight&,std::int64_t mass,std::uint32_t duration);
}
