#pragma once
#include "box_penetration.hpp"
#include "transit_progress.hpp"

namespace astra::ballistics {
// Internal authority state. Wire/save input must not bypass start_volume validation.
struct VolumeTransit {
    Flight flight;
    Vector entry{}, exit{};
    std::int64_t massMg{}, pathUm{}, elapsed{}, absorbedUj{};
    PenetrationTransit plan;
};
// Input must be on the entry boundary. rayEnd must follow its velocity and include the exit.
// No value means no confirmed traversable volume; never treat that as permission to pass through.
std::optional<VolumeTransit> start_volume(const Flight&, std::int64_t massMg,
    const Box&, const Vector& rayEnd, const Resistance&);
struct VolumeStep {
    VolumeTransit state;
    std::int64_t absorbedDeltaUj{};
    std::uint32_t consumed{}, remaining{};
    bool exited{};
};
// duration is 0..2^24 substep units. Reusing returned state does not repeat prior absorption.
VolumeStep advance_volume(const VolumeTransit&, std::uint32_t duration);
}
