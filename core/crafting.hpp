#pragma once
#include "world.hpp"
#include "sim_math.hpp"
#include <set>
namespace astra {
struct RecipeInput { std::uint32_t def{},quantity{};std::uint16_t minCondition{};std::uint8_t stage{}; };
struct RecipeOutput { std::uint32_t def{},quantity{};std::uint16_t probability{65535};std::uint8_t stage{255}; };
struct RecipeTool { std::uint32_t def{};std::uint16_t wear{}; };
struct Recipe {
    std::uint32_t id{},version{1},capabilities{},unlock{};std::uint8_t tier{1};
    std::uint64_t durationUs{},energyUj{};
    std::vector<std::uint16_t> stages{1000};
    std::vector<RecipeInput> inputs{};std::vector<RecipeOutput> outputs{};std::vector<RecipeTool> tools{};
    std::vector<std::uint32_t> prerequisites{};bool partialPower{};std::uint32_t repairDef{};
};
enum class JobPhase : std::uint8_t { Running,Paused,OutputReady,Collected,Cancelled,Destroyed };
struct CraftJob {
    Id entity,request,station,owner,escrow,source;
    std::uint64_t revision{1},progressUs{},energyUj{},seed{};
    std::uint32_t recipe{},version{},batch{1};std::uint8_t stage{};
    JobPhase phase{JobPhase::Running};
    std::vector<Id> inputs{},tools{},outputs{};
};
struct Station {
    Id entity,item,output,wreck,powerNode,owner;
    std::uint64_t revision{1};std::uint32_t capabilities{};Vec3 position;
    bool destroyed{};
};
struct Crafting { std::map<Id,CraftJob> jobs;std::map<Id,Station> stations;std::map<Id,Id> toolLeases; };
void validate_recipes(const Catalog&,const std::map<std::uint32_t,Recipe>&);
CraftJob start_craft(const Catalog&,World&,Crafting&,const Recipe&,Id station,Id owner,Id source,Id request,std::uint32_t batch,Id first,std::uint64_t event,const std::set<std::uint32_t>& unlocks);
void advance_craft(const Catalog&,World&,Crafting&,CraftJob&,const Recipe&,std::uint64_t dtUs,std::uint64_t availableUj,Id first,std::uint64_t event);
void cancel_craft(const Catalog&,World&,Crafting&,CraftJob&,bool destroyed);
void collect_craft(const Catalog&,World&,CraftJob&,Id target);
void place_item(const Catalog&,World&,Id item,Id target);
void consume_item(World&,Id item,std::uint32_t quantity);
}
