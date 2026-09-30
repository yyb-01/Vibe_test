#pragma once
#include "ballistic_collision.hpp"
#include "ballistic_energy.hpp"

namespace astra::ballistics {
struct BoxPassage {
    BoxHit contact;
    Vector entry{}, exit{}; // Quantized micrometres, independently of Q0.24 TOI.
    std::int64_t pathUm{};
    std::optional<EnergyTransfer> energy; // Unset until the same volume's exit is known.
};
// Static straight point path. Start outside/on the box, not inside an existing traversal.
// Supply an unexpanded volume, never a radius/curvature-padded broadphase box.
std::optional<BoxPassage> penetrate_box(const Vector& from, const Vector& to,
    const Box&, std::int64_t incomingUj, const Resistance&);
}
