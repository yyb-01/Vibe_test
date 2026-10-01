#pragma once
#include "sim_math.hpp"
#include "types.hpp"
#include <vector>
#include <map>
namespace astra {
enum class Region : std::uint8_t { Head,Thorax,Abdomen,Pelvis,LeftArm,RightArm,LeftLeg,RightLeg };
enum class LifeStatus : std::uint8_t { Conscious,Unconscious,Dead };
struct Wound {
    std::uint64_t event{};
    Region region{};
    double arterialMlS{},venousMlS{},treatment{1},pain{},fracture{};
    double depositedJ{};
};
struct Pathogen { double dose{},progress{}; std::uint64_t onsetTick{}; bool infected{}; };
struct Life {
    Id entity,account,inventory,corpse;
    std::uint64_t revision{1},tick{};
    std::uint32_t epoch{1};
    Vec3 position;
    double bloodMl{5000},hydrationMl{3000},energyKcal{2500},staminaJ{20000};
    double coreK{310.15},skinK{306.15},fatigue{},oxygenDebt{};
    double digestiveMl{},digestiveKcal{},heatExposure{},coldExposure{};
    std::array<double,8> health{100,100,100,100,100,100,100,100};
    std::vector<Wound> wounds{};
    std::map<std::uint32_t,Pathogen> pathogens{};
    LifeStatus status{LifeStatus::Conscious};
    bool cold{},hot{};
};
struct Environment {
    double airK{293.15},radiantK{293.15},windMS{},wetness{},insulation{1};
    double metabolicW{100},workW{},movementW{},massKg{80};
    bool resting{true},sheltered{};
};
void validate_life(const Life&);
void advance_life(Life&,const Environment&,std::uint64_t targetTick);
void wound(Life&,std::uint64_t event,Region,double energyJ,bool blunt,bool vital=false);
void wound_progress(Life&,std::uint64_t event,Region,double cumulativeJ,bool vital,double previousJ=-1);
Wound& injury_slot(Life&,std::uint64_t event,Region,double previousJ=0);
void treat_wound(Life&,std::uint64_t event,double bleedFactor,bool stabilize);
void ingest(Life&,double ml,double kcal,const std::map<std::uint32_t,double>& doses,std::uint64_t seed);
struct ArmorMap { std::array<std::uint8_t,256> integrity; ArmorMap(){integrity.fill(255);} };
double armor_integrity(const ArmorMap&,double u,double v);
void damage_armor(ArmorMap&,double u,double v,double depositJ,double radiusUV);
void damage_armor_progress(ArmorMap&,double u,double v,double totalJ,double previousJ,double radiusUV);
}
