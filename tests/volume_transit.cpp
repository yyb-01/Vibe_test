#include "check.hpp"
#include "volume_transit.hpp"

void volume_transit_checks() {
    using namespace astra;
    using namespace astra::ballistics;
    constexpr std::uint32_t tick = 1u << 24;
    Box box{{0, -10, -10}, {1000000, 10, 10}};
    Flight flight{{}, {3000000, 0, 0}};
    Resistance material{0, 4, 1, 1000000};
    auto begin = start_volume(flight, 1000000, box, {1000000, 0, 0}, material);
    CHECK(begin && begin->flight.position == Vector{} && begin->elapsed == 0);
    auto state = *begin;
    std::int64_t absorbed = state.absorbedUj;
    for (int i = 0; i < 120; ++i) {
        auto step = advance_volume(state, tick);
        CHECK(step.consumed == tick && step.remaining == 0 && step.exited == (i == 119));
        state = step.state; absorbed += step.absorbedDeltaUj;
        if (i == 59) CHECK(state.flight.position[0] == 625000 && state.flight.velocity[0] == 2000000);
    }
    CHECK(state.flight.position[0] == 1000000 && absorbed == 4000000);
    auto again = advance_volume(state, tick);
    CHECK(again.consumed == 0 && again.remaining == tick && !again.absorbedDeltaUj && again.exited);
    auto split = advance_volume(*begin, tick / 4);
    split = advance_volume(split.state, tick * 3 / 4);
    CHECK(split.state.flight == advance_volume(*begin, tick).state.flight);
    box.max[0] = 500000; material = {0, 0, 1, 1000000}; flight.velocity[0] = 240000000;
    auto thin = start_volume(flight, 1000000, box, {1000000, 0, 0}, material);
    CHECK(thin);
    auto exit = advance_volume(*thin, tick);
    CHECK(exit.consumed == tick / 2 && exit.remaining == tick / 2 && exit.exited);
    Atmosphere vacuum; vacuum.gravity = {};
    CHECK(free_flight(exit.state.flight, vacuum, 1, exit.remaining).position[0] == 1000000);
    CHECK(!start_volume(flight, 1000000, box, {100, 0, 0}, material)); // Exit unknown.
    rejects([&] { start_volume(flight, 1000000, box, {1000000, 10, 0}, material); }, Error::InvalidRequest);
    auto bad = *begin; bad.absorbedUj = 1;
    rejects([&] { advance_volume(bad, tick); }, Error::InvalidRequest);
    CHECK(begin->elapsed == 0 && begin->flight.position == Vector{} && begin->flight.velocity[0] == 3000000);
}
