#include "transit_progress.hpp"
#include "fixed_math.hpp"
#include "error.hpp"

namespace astra::ballistics {
TransitProgress transit_progress(const PenetrationTransit& plan, std::int64_t mass,
    std::int64_t path, std::int64_t elapsed) {
    require(plan.duration && *plan.duration > 0 && path > 0 && elapsed >= 0 && elapsed <= *plan.duration,
        Error::InvalidRequest);
    require(plan.energy.outgoingUj > 0 && plan.energy.outgoingUj <= 2000000000000LL &&
        plan.energy.depositedUj >= 0 && plan.energy.depositedUj <= 2000000000000LL - plan.energy.outgoingUj,
        Error::InvalidRequest);
    auto incoming = plan.energy.outgoingUj + plan.energy.depositedUj;
    auto entryEnergy = velocity_energy(plan.entryVelocity, mass);
    auto exitEnergy = velocity_energy(plan.exitVelocity, mass);
    require(exitEnergy == plan.energy.outgoingUj && entryEnergy >= exitEnergy && entryEnergy <= incoming,
        Error::InvalidRequest);
    TransitProgress result{};
    std::uint64_t startSquared = 0, endSquared = 0;
    for (std::size_t i = 0; i < 3; ++i) {
        auto a = plan.entryVelocity[i], b = plan.exitVelocity[i];
        require(a >= 0 ? b >= 0 && b <= a : b <= 0 && b >= a, Error::InvalidRequest);
        startSquared += static_cast<std::uint64_t>(a * a); endSquared += static_cast<std::uint64_t>(b * b);
        result.velocity[i] = a + fixed::mul_div(b - a, elapsed, *plan.duration);
    }
    auto speedSum = static_cast<std::int64_t>(fixed::sqrt_nearest(startSquared) + fixed::sqrt_nearest(endSquared));
    require(*plan.duration == fixed::mul_div(path, std::int64_t{480} * (1u << 24), speedSum), Error::InvalidRequest);
    auto currentEnergy = velocity_energy(result.velocity, mass);
    // Constant resistance makes path proportional to work. This remains monotone after rounding.
    result.travelledUm = entryEnergy == exitEnergy ? fixed::mul_div(path, elapsed, *plan.duration) :
        fixed::mul_div(path, entryEnergy - currentEnergy, entryEnergy - exitEnergy);
    result.absorbedUj = incoming - currentEnergy;
    result.exited = elapsed == *plan.duration;
    return result;
}
}
