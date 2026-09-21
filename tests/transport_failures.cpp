#include "session_fixture.hpp"
#include "transport.hpp"

void transport_failures() {
    SessionScenario f; auto info = f.host.info(); auto bad = info; ++bad.epoch;
    rejects([&] { HostTransport t(f.host, f.remote, bad); }, Error::EpochMismatch);
    auto peer = f.remote; peer.account = {};
    rejects([&] { HostTransport t(f.host, peer, info); }, Error::NotAccessible);
    CHECK(f.host.players() == 1);
    {
        HostTransport t(f.host, f.remote, info);
        rejects([&] { HostTransport duplicate(f.host, f.remote, info); }, Error::NotAccessible);
        auto size = t.output().size();
        rejects([&] { t.sent(size + 1); }, Error::InvalidRequest);
        CHECK(t.output().size() == size);
        CHECK(t.receive(encode_stream(f.packet()), f.access()) == 0);
        t.sent(size);
        const std::uint8_t prefix[]{0xff, 0xff, 0xff, 0x7f};
        rejects([&] { t.receive(prefix, {}); }, Error::InvalidRequest);
        CHECK(t.connection() == 0 && f.host.players() == 1);
    }
    for (std::size_t cut : {std::size_t(1), std::size_t(5)}) {
        HostTransport t(f.host, f.remote, info); t.sent(t.output().size());
        auto wire = encode_stream(f.packet());
        CHECK(t.receive(std::span(wire).first(cut), {}) == cut);
        rejects([&] { t.finish(); }, Error::InvalidRequest);
        CHECK(t.connection() == 0 && f.host.players() == 1);
    }
    {
        HostTransport t(f.host, f.remote, info); t.sent(t.output().size());
        auto packet = f.packet(); packet[0] = 0;
        rejects([&] { t.receive(encode_stream(packet), {}); }, Error::Incompatible);
        CHECK(t.connection() == 0 && f.s.probe->saves == 0);
    }
    {
        HostTransport t(f.host, f.remote, info);
        std::thread wrong([&] { rejects([&] { t.output(); }, Error::InvalidState); });
        wrong.join();
    }
    CHECK(f.host.players() == 1);
    // Admission succeeds, resume fails on the per-account rate limit: no leaked slot.
    for (int n = 0; n < 30; ++n) {
        try { HostTransport t(f.host, f.remote, info); }
        catch (const Violation& e) { CHECK(e.code == Error::Busy); }
        CHECK(f.host.players() == 1);
    }
}
