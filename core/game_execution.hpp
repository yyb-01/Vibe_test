#pragma once
#include "game_command.hpp"
namespace astra {
bool reload_busy(const World&,const GameState&,Id item);
void check_reload_access(const World&,const GameState&,const GameCommand&);
void abort_reload(const World&,WeaponRuntime&);
bool accessible_container(const GameDefinitions&,const World&,const GameState&,Id actor,Id container);
bool player_action(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t);
bool economy_action(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t);
bool building_action(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t);
bool ground_action(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t);
void integrate_vehicle(Vehicle&,const VehicleForces&,const MassProperties&);
void tick_vehicles(const GameDefinitions&,GameState&);
bool vehicle_action(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t);
bool combat_action(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t);
void simulation_tick(const GameDefinitions&,World&,GameState&,GameIds&,std::uint64_t);
void finish_deaths(const GameDefinitions&,World&,GameState&,GameIds&,std::uint64_t);
void run_ballistics(const GameDefinitions&,World&,GameState&,std::uint64_t event);
bool belongs_to(const World&,Id item,Id root);
Id actor_inventory(const GameState&,const GamePeer&);
void take_materials(World&,Id source,std::uint32_t def,std::uint64_t quantity);
}
