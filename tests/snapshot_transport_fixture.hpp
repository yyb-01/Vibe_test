#pragma once
#include "client_transport_fixture.hpp"
#include <algorithm>

// Transfer one frame only; re-observe authority for every partial write.
inline void snapshot_frame(HostTransport& host, ClientTransport& client, std::uint64_t token,
                            const InteractionState& observation, std::size_t chunk = 7) {
    auto remaining = host.snapshot_output(observation).size(); CHECK(remaining);
    while (remaining) {
        auto bytes = host.snapshot_output(observation).first(std::min(chunk, remaining));
        auto n = bytes.size(); CHECK(client.receive_snapshot(token, bytes) == n);
        host.snapshot_sent(n); remaining -= n;
    }
}
