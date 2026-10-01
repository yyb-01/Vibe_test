#pragma once
#include "types.hpp"
namespace astra {
struct PlayerControl {
    std::uint32_t inputSeq{};std::uint64_t moveTick{},aimTick{};
    std::int16_t yaw{},pitch{};Id vehicle,weapon,armor;
    bool connected{true},everJoined{true};std::uint64_t disconnectTick{};
};
inline bool active_player(const PlayerControl& c,std::uint64_t tick){return c.connected||(c.everJoined&&tick>=c.disconnectTick&&tick-c.disconnectTick<=600);}
}
