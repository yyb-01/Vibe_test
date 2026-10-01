#pragma once
#include "sim_math.hpp"
#include "types.hpp"
#include <map>
#include <vector>
namespace astra {
enum class StructureKind : std::uint8_t { Foundation,Wall,Floor,Roof,Door,Barricade,Trap,Utility };
struct StructureDef {
    std::uint32_t id{};StructureKind kind{};Vec3 halfExtent{.5,.5,.5};
    std::uint64_t massG{10000},maxCargoG{},capacityG{100000};double maxSpanM{5},maxSlopeRad{.3};
    std::uint16_t health{1000};std::vector<std::pair<std::uint32_t,std::uint32_t>> materials{};
};
struct Support { Id parent;std::uint16_t share{65535};std::uint64_t capacityG{100000}; };
struct Structure {
    Id entity,owner;std::uint64_t revision{1},lastDamageEvent{},lastTriggerTick{};
    std::uint32_t definition{};Vec3 position;std::uint16_t health{1000};
    std::uint64_t bornTick{},removedTick{};
    std::vector<Support> supports{};bool destroyed{},open{},locked{},armed{};
};
struct BuildObservation { Vec3 player;double groundZ{},slopeRad{};bool terrainClear{},navigationClear{},allowed{},lineOfSight{}; };
Vec3 normalize_build(Vec3);
void validate_build(const Structure&,const StructureDef&,const std::map<Id,Structure>&,const std::map<std::uint32_t,StructureDef>&,const BuildObservation&);
std::vector<Id> unsupported(const std::map<Id,Structure>&,const std::map<std::uint32_t,StructureDef>&);
bool shelter(Vec3,const std::map<Id,Structure>&,const std::map<std::uint32_t,StructureDef>&);
}
