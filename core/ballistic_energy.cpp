#include "ballistic_energy.hpp"
#include "fixed_math.hpp"
#include "error.hpp"

namespace astra::ballistics {
std::int64_t kinetic_energy(std::int64_t mass, std::int64_t speed) {
    require(mass > 0 && mass <= 1000000 && speed >= 0 && speed <= 2000000000LL, Error::InvalidRequest);
    return fixed::mul_div(speed * speed, mass, 2000000000000LL);
}
EnergyTransfer penetrate(std::int64_t incoming, std::int64_t path, const Resistance& material) {
    require(incoming >= 0 && path > 0 && material.entryUj >= 0 && material.resistanceUjPerUm >= 0 &&
            material.minPathUm > 0 && material.maxPathUm >= material.minPathUm, Error::InvalidRequest);
    EnergyTransfer stopped{0, incoming};
    // Never shorten a path outside the calibrated domain to make penetration easier.
    if (path < material.minPathUm || path > material.maxPathUm || material.entryUj >= incoming) return stopped;
    auto budget = incoming - material.entryUj;
    if (material.resistanceUjPerUm && path > budget / material.resistanceUjPerUm) return stopped;
    auto deposited = material.entryUj + material.resistanceUjPerUm * path;
    return {incoming - deposited, deposited};
}
EnergyTransfer ricochet_energy(std::int64_t incoming, std::uint16_t keep) {
    require(incoming >= 0, Error::InvalidRequest);
    auto outgoing = fixed::mul_div(incoming, keep, UINT16_MAX);
    return {outgoing, incoming - outgoing};
}
Deposit split_deposit(std::int64_t deposited, std::uint16_t blunt, std::uint16_t spall) {
    require(deposited >= 0 && std::uint32_t(blunt) + spall <= UINT16_MAX, Error::InvalidRequest);
    auto body = fixed::mul_div(deposited, blunt, UINT16_MAX);
    auto fragments = fixed::mul_div(deposited, spall, UINT16_MAX);
    require(body <= deposited && fragments <= deposited - body, Error::InvalidState);
    return {deposited - body - fragments, body, fragments};
}
}
