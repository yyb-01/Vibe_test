#pragma once
#include "sim_math.hpp"
#include "types.hpp"
namespace astra {
struct GroundAsset {Id item,owner;Vec3 position{},velocity{},omega{};std::uint32_t lifeEpoch{},spawnDef{},quantity{};std::uint64_t cycle{},nextSpawnTick{};};
}
