#pragma once
#include "inventory.hpp"
#include <array>

namespace astra {
using Grid = std::array<std::uint32_t, 32>;
inline void occupy(Grid& grid, const Container& c, const ItemDef& d, const Placement& p) {
    require(p.rotation <= 1 && p.reserved == 0, Error::InvalidPlacement);
    require(p.kind == c.kind, Error::InvalidPlacement);
    if (c.kind == PlaceKind::World) {
        require(!p.x && !p.y && !p.rotation && !p.socketId, Error::InvalidPlacement);
        return;
    }
    if (c.kind == PlaceKind::Slot) {
        require(!p.x && !p.y && !p.rotation, Error::InvalidPlacement);
        require(p.socketId > 0 && p.socketId <= c.state.width, Error::InvalidPlacement);
        auto bit = std::uint32_t{1} << (p.socketId - 1);
        require(!(grid[0] & bit), Error::InvalidPlacement);
        grid[0] |= bit;
        return;
    }
    require(c.kind == PlaceKind::Grid && !p.socketId, Error::InvalidPlacement);
    unsigned w = p.rotation ? d.gridH : d.gridW;
    unsigned h = p.rotation ? d.gridW : d.gridH;
    require(p.x + w <= c.state.width && p.y + h <= c.state.height, Error::InvalidPlacement);
    auto mask = w == 32 ? UINT32_MAX : (std::uint32_t{1} << w) - 1;
    mask <<= p.x;
    for (unsigned y = p.y; y < p.y + h; ++y) {
        require(!(grid[y] & mask), Error::InvalidPlacement);
        grid[y] |= mask;
    }
}
}
