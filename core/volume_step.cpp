#include "volume_transit.hpp"
#include "fixed_math.hpp"
#include "error.hpp"
#include <algorithm>

namespace astra::ballistics {
VolumeStep advance_volume(const VolumeTransit& input, std::uint32_t duration) {
    require(duration <= (1u << 24), Error::InvalidRequest);
    auto before = transit_progress(input.plan, input.massMg, input.pathUm, input.elapsed);
    auto position = [&](std::int64_t distance) {
        Vector result{};
        for (std::size_t i = 0; i < 3; ++i) {
            require(input.entry[i] >= -8000000000LL && input.entry[i] <= 8000000000LL &&
                input.exit[i] >= -8000000000LL && input.exit[i] <= 8000000000LL, Error::InvalidRequest);
            result[i] = input.entry[i] + fixed::mul_div(input.exit[i] - input.entry[i], distance, input.pathUm);
        }
        return result;
    };
    require(input.flight.position == position(before.travelledUm) && input.flight.velocity == before.velocity &&
        input.absorbedUj == before.absorbedUj, Error::InvalidRequest);
    auto consumed = static_cast<std::uint32_t>(std::min<std::int64_t>(duration, *input.plan.duration - input.elapsed));
    VolumeStep result{input, 0, consumed, duration - consumed, false};
    result.state.elapsed += consumed;
    auto after = transit_progress(input.plan, input.massMg, input.pathUm, result.state.elapsed);
    result.state.flight = {position(after.travelledUm), after.velocity};
    result.state.absorbedUj = after.absorbedUj;
    result.absorbedDeltaUj = after.absorbedUj - before.absorbedUj;
    result.exited = after.exited;
    return result;
}
}
