#pragma once
#include "survival.hpp"
#include "structures.hpp"
#include <deque>
#include <span>
namespace astra {
enum class PinReason : std::uint8_t { Player,Vehicle,Projectile,Transaction,Craft,Destruction,Save };
struct Cell {
    std::array<std::uint16_t,7> pins{};std::uint64_t dirtyRevision{},savedRevision{};
    bool loaded{},wanted{};
};
struct Observer { Vec3 position;bool driving{}; };
std::array<bool,1024> active_cells(std::span<const Observer>);
unsigned cell_of(Vec3);
void pin(Cell&,PinReason,int delta);
bool can_unload(const Cell&);
double loading_distance(double maxSpeed,double p99LoadS,double safetyS,double brakingMS2);
bool line_of_sight(Vec3,Vec3,const std::map<Id,Structure>&,const std::map<std::uint32_t,StructureDef>&);
enum class StimulusKind : std::uint8_t { Gunshot,Engine,Machine,Impact,Heat };
struct Stimulus {
    std::uint64_t event{},tick{};Id source;Vec3 position;
    StimulusKind kind{};double radiusM{100},soundDb{100},heatWatts{};std::uint32_t durationTicks{60};
};
class StimulusQueue {
public:
    void publish(const Stimulus&);
    std::vector<Stimulus> take(std::uint64_t tick);
private: std::deque<Stimulus> queue_;
};
enum class ZombieMode : std::uint8_t { Idle,Investigate,Chase,Attack,Dead };
struct Zombie {
    Id entity,target;Vec3 position,investigate;
    std::uint64_t revision{1},lastAttackTick{},lastStimulus{};
    double health{100},hearingDb{25},speedMS{2};ZombieMode mode{};
};
struct WorldSimulation { std::array<Cell,1024> cells;std::map<Id,Zombie> zombies;std::uint32_t pathBudget{4};std::vector<Stimulus> stimuli; };
void publish_stimulus(WorldSimulation&,const Stimulus&);
struct ZombieAttack { Id zombie,victim;std::uint64_t tick{}; };
std::vector<ZombieAttack> update_zombies(WorldSimulation&,const std::map<Id,Life>&,const std::map<Id,Structure>&,
    const std::map<std::uint32_t,StructureDef>&,std::span<const Stimulus>,std::uint64_t tick);
std::vector<Vec3> find_path(Vec3,Vec3,const std::map<Id,Structure>&,const std::map<std::uint32_t,StructureDef>&,unsigned maxNodes=2048);
}
