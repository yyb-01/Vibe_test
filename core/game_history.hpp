#pragma once
#include "survival.hpp"
#include <optional>
namespace astra {
struct HistoryArmor {Id item;ArmorMap integrity;};
struct HistoryActor {
    Id entity;std::uint32_t epoch{1};std::uint8_t kind{};
    Vec3 position;std::int16_t yaw{},pitch{};bool alive{true};std::optional<HistoryArmor> armor;
};
struct HistoryDoor {Id entity;bool open{},destroyed{};};
struct HistoryFrame {std::uint64_t tick{};std::vector<HistoryActor> actors;std::vector<HistoryDoor> doors;};
struct GameState;struct World;
void record_history(const World&,GameState&);
std::vector<HistoryActor> historical_actors(const GameState&,std::uint64_t q16);
bool historical_door(const GameState&,Id,std::uint64_t q16);
}
