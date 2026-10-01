#pragma once
#include "game_state.hpp"
#include "durable.hpp"
#include "simulation_identity.hpp"
namespace astra {
inline constexpr Id ground_root{0x415354524147414dULL,2};
inline constexpr Id station_root{0x415354524147414dULL,3};
enum class GameOperation : std::uint8_t {
    Move,Aim,Attach,Detach,Reload,Fire,Trigger,ClearJam,Consume,Treat,
    Craft,Cancel,Collect,Build,Destroy,Door,ArmTrap,EnterVehicle,ExitVehicle,Drive,
    DetachVehicle,ConnectPower,Refuel,Loot,Respawn,Tick,
    InventoryMove,InventorySwap,InventorySplit,InventoryMerge,Drop,Equip,Presence,AttachVehicle,Lock
};
struct GameCommand {
    Id id;GameOperation operation{};std::uint32_t lifeEpoch{1},sequence{},definition{},quantity{1};
    std::array<Id,3> targets{};Vec3 position;std::uint64_t tick{},revision{},event{};
    std::int16_t yaw{},pitch{};std::int8_t gear{2};
    double throttle{},brake{},steer{};bool enabled{};
    bool operator==(const GameCommand&) const=default;
};
struct GamePeer { Id account,actor;bool host{},local{true},clockReady{};std::int32_t clockOffset{};std::uint8_t viewDelay{}; };
struct GameIds {
    Id first;std::uint32_t capacity{},used{};
    Id take(unsigned count=1){require(count<=capacity-used,Error::LimitExceeded);Id out{first.hi,first.lo+used};used+=count;return out;}
};
std::vector<std::uint8_t> encode_command(const GameCommand&);
GameCommand decode_command(const std::vector<std::uint8_t>&);
std::uint16_t game_allocation_budget(const GameDefinitions&,const GameState&,const GameCommand&);
void validate_game_world(const GameDefinitions&,const World&,const GameState&);
void execute_game(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t event);
class GameRuntime {
public:
    GameRuntime(DurableInventory&,GameDefinitions);
    Result dispatch(const GameCommand&,const GamePeer&);
    GameState state() const;
    const GameDefinitions& definitions() const {return definitions_;}
private:
    DurableInventory& inventory_;const GameDefinitions definitions_;
    mutable std::mutex cacheMutex_;
    mutable std::optional<GameState> cached_;
    mutable std::uint64_t cachedRevision_{UINT64_MAX};
};
GameDefinitions survival_definitions();
Checkpoint survival_seed(const GameDefinitions&,unsigned players=1);
}
