#include "fire_receipt.hpp"
#include "fixed_math.hpp"
#include <algorithm>
#include <cstdlib>

namespace astra {
ShotAccepted visual_shot(std::uint64_t shotId, const ShotData& data) {
    validate_shot(data);
    require(shotId && shotId <= INT64_MAX, Error::InvalidRequest);
    ShotAccepted s; s.shotId = shotId; s.assemblyRevision = data.intent.assemblyRevision;
    s.fireSeq = data.intent.fireSeq; s.launchTick = static_cast<std::uint32_t>(data.effectiveQ16 >> 16);
    s.ammoDef = data.ammoDef; s.visualSeed = data.visualSeed;
    auto velocity = data.launch.velocity;
    std::int64_t largest = 0; std::uint64_t square = 0;
    for (auto v : velocity) { largest = std::max(largest, std::abs(v)); square += std::uint64_t(v * v); }
    s.speed = static_cast<std::uint16_t>(fixed::mul_div(fixed::sqrt_nearest(square), 1, 100000));
    // Scale small velocities before normalization to retain diagonal direction precision.
    while (largest < 1000000000) { for (auto& v : velocity) v *= 2; largest *= 2; }
    square = 0;
    for (auto v : velocity) square += std::uint64_t(v * v);
    auto length = static_cast<std::int64_t>(fixed::sqrt_nearest(square));
    for (unsigned i = 0; i < 3; ++i) {
        auto p = data.launch.position[i], cell = p / 125000000, local = p % 125000000;
        if (local < 0) { --cell; local += 125000000; }
        s.cell[i] = static_cast<std::int16_t>(cell);
        s.localPosition[i] = static_cast<std::uint32_t>(local);
        s.direction[i] = static_cast<std::int16_t>(fixed::mul_div(velocity[i], 32767, length));
    }
    return s;
}
void validate_fire_receipt(const FireReceipt& r) {
    require(r.accepted.has_value() == (r.status == TransactionStatus::Committed), Error::InvalidRequest);
    validate_receipt({{fire_request_namespace, r.fireSeq}, r.status, r.reason,
                     r.accepted ? r.accepted->shotId : 0, 1});
    if (!r.accepted) return;
    const auto& s = *r.accepted;
    require(s.fireSeq == r.fireSeq && s.assemblyRevision && s.assemblyRevision <= INT64_MAX &&
            s.ammoDef && s.speed <= 20000, Error::InvalidRequest);
    std::int64_t square = 0;
    for (unsigned i = 0; i < 3; ++i) {
        auto p = std::int64_t(s.cell[i]) * 125000000 + s.localPosition[i];
        require(s.localPosition[i] < 125000000 && std::abs(p) <= 8000000000LL &&
                s.direction[i] != INT16_MIN, Error::InvalidRequest);
        square += std::int64_t(s.direction[i]) * s.direction[i];
    }
    require(std::abs(square - 32767LL * 32767) <= 60000, Error::InvalidRequest);
}
}
