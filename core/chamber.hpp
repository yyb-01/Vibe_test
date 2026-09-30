#pragma once
#include "inventory.hpp"

namespace astra {
inline constexpr std::uint8_t chamber_container = 1;
inline constexpr std::uint8_t magazine_container = 2;
struct Chamber { Id container, round; };
// Host ledger lookup; empty/missing chamber has no round. No cached boolean grants a shot.
Chamber chamber_state(const World&, Id weapon);
void validate_chambers(const Catalog&, const World&);
// One-round loading through existing atomic Move/Split. Caller supplies authority/identity and compatible ammo.
Request chamber_request(const World&, Id weapon, Id ammo, Id requestId, std::uint64_t actionSeq,
                        std::uint64_t lease);
}
