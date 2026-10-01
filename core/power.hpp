#pragma once
#include "sim_math.hpp"
#include "types.hpp"
#include <map>
#include <vector>
namespace astra {
struct PowerNode {
    Id entity;Vec3 position;std::uint32_t generateW{},demandW{},chargeW{},dischargeW{};
    std::uint64_t batteryUj{},capacityUj{},fuelUj{};
    std::uint16_t chargeEfficiency{65535},dischargeEfficiency{65535};
    std::uint8_t priority{};bool partial{},renewable{};
};
struct Cable { Id a,b;double maxLengthM{100}; };
struct PowerGrid { std::map<Id,PowerNode> nodes;std::vector<Cable> cables; };
struct EnergyBatch {
    std::map<Id,std::uint64_t> deliveredUj;
    std::uint64_t generatedUj{},initialBatteryUj{},finalBatteryUj{},loadUj{},lossUj{},unusedUj{};
};
// One allocation is an economic batch; persist nodes and dependent craft stages together.
EnergyBatch allocate_power(PowerGrid&,std::uint32_t durationUs);
}
