#pragma once
#include "weapons.hpp"
#include "crafting.hpp"
#include "power.hpp"
#include "world_simulation.hpp"
#include "shot_simulation.hpp"
#include "game_control.hpp"
#include "game_ground.hpp"
#include "game_history.hpp"
#include "beam.hpp"
namespace astra {
inline constexpr Id game_root{0x415354524147414dULL,1};
struct FoodProfile { double waterMl{},energyKcal{};std::map<std::uint32_t,double> pathogens{}; };
struct GameDefinitions {
    std::uint32_t version{1};Catalog items;
    std::map<std::uint32_t,PartProfile> parts;
    std::map<std::uint32_t,AmmoProfile> ammunition;
    std::map<std::uint32_t,ReceiverProfile> receivers;
    std::map<std::uint32_t,Recipe> recipes;
    std::map<std::uint32_t,StructureDef> structures;
    std::map<std::uint32_t,FoodProfile> foods;
    EngineDef engine;std::vector<WheelDef> wheels;
};
struct GameShot {
    ShotFlight flight;Id shooter;std::uint32_t ammoDef{};std::uint8_t viewDelay{};
    std::optional<BeamTransit> transit;
    std::map<std::uint16_t,std::int64_t> damageUj;
};
struct GameState {
    std::uint32_t catalogVersion{1};std::uint64_t revision{1},tick{},nextShot{1};
    std::map<Id,Life> lives;
    std::map<Id,PlayerControl> controls;
    std::map<Id,WeaponRuntime> weapons;
    std::map<Id,ArmorMap> armor;
    std::map<Id,Vehicle> vehicles;
    std::map<Id,DriveInput> drivingInputs;
    std::map<Id,GroundAsset> groundAssets;
    std::vector<HistoryFrame> history;
    Crafting crafting;PowerGrid power;
    std::map<Id,Structure> structures;
    WorldSimulation world;
    std::vector<GameShot> shots;
    std::map<Id,std::uint64_t> lootCycles;
    std::map<Id,std::vector<std::uint32_t>> unlocks;
};
void validate_definitions(const GameDefinitions&);
void validate_game(const GameState&);
std::vector<std::uint8_t> encode_game(const GameState&);
GameState decode_game(const std::vector<std::uint8_t>&);
}
