#include "client_state.hpp"

namespace astra {
void ClientState::set_roots(std::set<Id> roots) {
    require(roots.size() <= 16 && !roots.contains(Id{}), Error::InvalidRequest);
    roots_ = std::move(roots); view_.reset(); assembly_.reset();
}
void ClientState::begin_snapshot(const SnapshotDescriptor& d) {
    require(!roots_.empty(), Error::NotAccessible);
    (void)snapshot_pages(d);
    require(d.epoch == epoch_, Error::EpochMismatch);
    // HostSession IDs increase within an epoch, including equal-sequence view refreshes.
    require(d.id.hi == epoch_ && d.id.lo, Error::InvalidRequest);
    require(d.sequence >= published_ && d.sequence >= confirmed_, Error::RevisionConflict);
    if (latest_) {
        require(d.id >= latest_->id, Error::RevisionConflict);
        if (d.id == latest_->id) { require(d == *latest_, Error::InvalidState); return; }
    }
    assembly_.reset(); // Never retain two 2MiB reassembly buffers.
    auto next = std::make_unique<SnapshotAssembly>(d);
    latest_ = d; assembly_ = std::move(next);
}
bool ClientState::receive_page(const std::vector<std::uint8_t>& frame) {
    require(bool(assembly_), Error::InvalidState);
    assembly_->receive(frame);
    if (!assembly_->complete()) return false;
    try {
        auto world = decode_view(assembly_->bytes(), catalog_);
        std::set<Id> roots;
        for (const auto& [id, c] : world.containers) if (!c.state.ownerItem) roots.insert(id);
        require(roots == roots_, Error::NotAccessible);
        auto next = std::make_shared<const World>(std::move(world));
        view_ = std::move(next); published_ = latest_->sequence;
        assembly_.reset(); return true;
    } catch (...) { assembly_.reset(); throw; }
}
}
