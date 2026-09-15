#include "session.hpp"

namespace astra {
SnapshotDescriptor HostSession::start_snapshot(std::uint64_t connection, std::uint64_t token,
                                                const InteractionState& state) {
    auto roots = view(connection, token, state);
    require(nextSnapshot_ < revision_limit, Error::LimitExceeded);
    auto& p = peer(connection); p.snapshot.reset();
    auto data = std::make_unique<SnapshotData>();
    data->bytes = encode_view(roots);
    data->descriptor = {{info_.epoch, nextSnapshot_++}, info_.epoch, roots.sequence,
                        static_cast<std::uint32_t>(data->bytes.size())};
    auto descriptor = data->descriptor; p.snapshot = std::move(data);
    return descriptor;
}
std::vector<std::uint8_t> HostSession::snapshot_page(std::uint64_t connection, Id id,
                                                   std::size_t page, const InteractionState& state) {
    owner(); auto& p = admit_command(connection);
    try { (void)authorize(p, p.lease.token, state); }
    catch (...) { p.snapshot.reset(); throw; }
    require(p.snapshot && p.snapshot->descriptor.id == id, Error::NotAccessible);
    return encode_snapshot_page(*p.snapshot, page);
}
}
