#pragma once
#include "projectile.hpp"

namespace astra::ballistics {
struct RicochetGate {
    std::uint16_t cosThreshold{}; // UNORM16, strict mu < threshold.
    std::uint32_t probabilityQ16{}; // Inclusive 0..65536; 65536 always passes the draw.
    bool ammoAllowed{};
    std::uint64_t serverSeed{};
};
// Caller supplies authoritative calibrated probability, including energy/local-condition effects.
bool approve_ricochet(const BarrierImpact&, std::int64_t massMg,
    std::uint16_t lifetimeContact, const RicochetGate&);
}
