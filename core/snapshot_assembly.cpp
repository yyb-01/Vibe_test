#include "snapshot.hpp"
#include "checkpoint_wire.hpp"
#include <algorithm>

namespace astra {
SnapshotAssembly::SnapshotAssembly(SnapshotDescriptor d) : descriptor_(d) {
    (void)snapshot_pages(d); data_.resize(d.bytes);
}
void SnapshotAssembly::receive(const std::vector<std::uint8_t>& frame) {
    require(frame.size() > snapshot_page_header + 8 && frame.size() <= snapshot_page_limit, Error::InvalidRequest);
    Reader tail{frame, frame.size() - 8};
    require(tail.get(8) == checkpoint_wire::checksum(frame, frame.size() - 8), Error::InvalidRequest);
    Reader r{frame}; require(r.get(4) == 0x31505341, Error::Incompatible);
    SnapshotDescriptor d; d.id = r.id(); d.epoch = r.get(8); d.sequence = r.get(8);
    auto page = r.get(2), count = r.get(2); d.bytes = r.get(4);
    require(d == descriptor_ && count == snapshot_pages(d) && page < count, Error::InvalidRequest);
    auto start = page * snapshot_page_data;
    auto size = std::min(snapshot_page_data, data_.size() - start);
    require(frame.size() == snapshot_page_header + size + 8, Error::InvalidRequest);
    auto begin = frame.begin() + snapshot_page_header, end = begin + size;
    auto target = data_.begin() + start;
    auto bit = std::uint64_t{1} << page;
    if (received_ & bit) require(std::equal(begin, end, target), Error::InvalidRequest);
    else { std::copy(begin, end, target); received_ |= bit; }
}
bool SnapshotAssembly::complete() const {
    return received_ == (std::uint64_t{1} << snapshot_pages(descriptor_)) - 1;
}
const std::vector<std::uint8_t>& SnapshotAssembly::bytes() const {
    require(complete(), Error::Pending); return data_;
}
}
