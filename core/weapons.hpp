#pragma once
#include "vehicle.hpp"
#include "world.hpp"
#include "fire_validation.hpp"
#include <span>
namespace astra {
struct MountSocket { std::uint32_t id{},profile{};Vec3 position;bool required{}; };
struct PartProfile {
    std::uint32_t id{},mountProfile{},family{},chamberProfile{};std::uint64_t tags{},requiredTags{},forbiddenTags{};
    Vec3 com,halfExtent{.05,.05,.05};Mat3 inertia{diagonal(.01,.01,.01)};
    std::vector<MountSocket> sockets{};
    double ergonomics{},velocityScale{1},dispersionRad{},recoilScale{1};
};
struct AmmoProfile {
    std::uint32_t id{},family{},chamberProfile{};std::int64_t massMg{8000},speedUmS{900000000},radiusUm{500};
    std::vector<std::pair<std::uint32_t,std::uint32_t>> dragMach{{0,1},{65536,2},{131072,1}};
    std::uint32_t soundSpeedUmS{343000000};bool ricochet{};
};
struct ReceiverProfile {
    std::uint32_t id{},family{},chamberProfile{},magazineSocket{3};
    std::uint32_t firePeriodTicks{6},reloadStepTicks{30};
    std::uint16_t wearPerShot{1};double heatPerShotK{2},coolingPerS{.5},baseJamProbability{};
    bool automatic{},singleChamber{true};
};
struct WeaponStats { double massKg{};Vec3 com;Mat3 inertia;double ergonomics{},velocityScale{1},dispersionRad{},recoilScale{1};std::uint64_t revisionHash{}; };
enum class WeaponPhase : std::uint8_t { Idle,ExtractMagazine,InsertMagazine,Chamber,Ready,Jammed };
struct WeaponRuntime {
    Id item,owner,selectedMagazine,oldMagazine;std::uint32_t netId{},inputSeq{},fireSeq{};std::uint16_t generation{1};
    std::uint64_t revision{1},assemblyRevision{1},nextPhaseTick{},lastFireTick{},shotCounter{},lastEffectiveQ16{};
    WeaponPhase phase{WeaponPhase::Ready};double heatK{293.15},fouling{},recoilPitch{},recoilYaw{};
    bool trigger{};
};
WeaponStats weapon_stats(const Catalog&,const World&,Id,const std::map<std::uint32_t,PartProfile>&,bool functional=true);
void attach_part(const Catalog&,World&,Id item,Id targetSocket,std::uint32_t ordinal,const std::map<std::uint32_t,PartProfile>&);
void feed_round(const Catalog&,World&,Id weapon,Id magazine,Id newId,std::uint64_t event,const std::map<std::uint32_t,AmmoProfile>&,const ReceiverProfile&);
void begin_reload(WeaponRuntime&,const World&,Id magazine,const ReceiverProfile&,std::uint64_t tick);
void step_reload(const Catalog&,World&,WeaponRuntime&,const ReceiverProfile&,std::uint64_t tick,Id bag,Id newId,std::uint64_t event,const std::map<std::uint32_t,AmmoProfile>&);
}
