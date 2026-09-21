#pragma once
#include "../core/transport.hpp"
#include "../core/client_transport.hpp"
#include <algorithm>

// In-process reliable streams only. No queue, socket or authentication emulation.
// Each tick moves at most chunk bytes per direction/channel; chunk=0 simulates blockage.
inline std::size_t transport_tick(astra::HostTransport& host, astra::ClientTransport& client,
    std::uint64_t token, const astra::InteractionState& observation, std::size_t chunk = 256) {
    auto live = [&] { return host.poll() && client.poll(token); };
    auto stop = [&] { host.disconnect(); client.disconnect(token); };
    std::size_t moved = 0;
    try {
        if (!live()) { stop(); return 0; }
        auto out = client.output(token);
        if (!out.empty()) {
            auto n = host.receive(out.first(std::min(chunk, out.size())), observation);
            client.sent(token, n); moved += n;
        }
        if (!live()) { stop(); return moved; }
        out = host.output();
        if (!out.empty()) {
            auto n = client.receive(token, out.first(std::min(chunk, out.size())));
            host.sent(n); moved += n;
        }
        if (!live()) { stop(); return moved; }
        try { out = host.snapshot_output(observation); }
        catch (const astra::Violation& e) {
            if (e.code == astra::Error::Busy) return moved;
            throw;
        }
        if (!out.empty()) {
            auto n = client.receive_snapshot(token, out.first(std::min(chunk, out.size())));
            host.snapshot_sent(n); moved += n;
        }
        return moved;
    } catch (...) { stop(); throw; }
}
