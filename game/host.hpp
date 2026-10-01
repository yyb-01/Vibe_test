#pragma once
#include "game_command.hpp"
#include "async_store.hpp"
#include "sqlite.hpp"
#include <sstream>
namespace astra::native {
struct Host {
    GameDefinitions definitions{survival_definitions()};
    std::unique_ptr<DurableInventory> inventory;
    std::unique_ptr<GameRuntime> game;
    std::array<std::pair<std::int32_t,std::uint64_t>,21> fireClocks{};
    explicit Host(const std::filesystem::path&);
    std::string execute(const std::string&);
    std::string view(unsigned slot) const;
    bool close();
};
Id parse_id(const std::string&);
GameCommand command(std::istringstream&,const GameState&,const GamePeer&,Id,const std::optional<GameCommand>&);
GameCommand remote_fire(std::istringstream&,Id,std::uint64_t,bool);
std::string id_text(Id);
}
