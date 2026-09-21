#include "client_transport_fixture.hpp"

namespace {
using Clock = TransportDeadlines::Clock;
using namespace std::chrono_literals;
}
void transport_deadlines() {
    static Clock::time_point time;
    auto now = +[] { return time; };
    time = {};
    rejects([&] { TransportDeadlines d(0s, now); }, Error::InvalidRequest);
    rejects([] { TransportDeadlines d(1s, nullptr); }, Error::InvalidRequest);
    TransportDeadlines d(1s, now); d.begin(TransportDeadlines::Read);
    time += 999ms; CHECK(!d.expired()); d.begin(TransportDeadlines::Read);
    time += 1ms; CHECK(d.expired()); d.reset(); CHECK(!d.expired());
    time -= 1ms; rejects([&] { d.expired(); }, Error::InvalidState);
    time = Clock::time_point::max();
    rejects([&] { TransportDeadlines edge(1s, now); }, Error::InvalidState);

    for (int mode = 0; mode < 4; ++mode) {
        time = {}; SessionScenario f;
        HostTransport host(f.host, f.remote, f.host.info(), 1s, now);
        if (mode != 0) {
            host.sent(host.output().size()); time += 2s;
            CHECK(host.poll()); // No operation pending: idle is allowed.
            auto wire = encode_stream(f.packet());
            if (mode == 1) CHECK(host.receive(std::span(wire).first(1), {}) == 1);
            if (mode == 2) CHECK(host.receive(wire, f.access()) == wire.size());
            if (mode == 3) CHECK(host.shutdown().applied());
        }
        time += 999ms; CHECK(host.poll());
        if (mode == 1) {
            const std::uint8_t byte = 0; CHECK(host.receive({&byte, 1}, {}) == 1);
        } else host.sent(1);
        time += 1ms;
        rejects([&] { host.sent(0); }, Error::InvalidState);
        CHECK(!host.poll() && !host.connection() && host.output().empty());
        CHECK(f.host.players() == 1);
    }
    time = {}; SessionScenario f;
    HostTransport host(f.host, f.remote, f.host.info(), 1s, now);
    time -= 1ms; rejects([&] { host.poll(); }, Error::InvalidState);
    CHECK(!host.connection());
}
