#include "snapshot.hpp"
#include "checkpoint_wire.hpp"
#include <algorithm>

namespace astra {
std::size_t snapshot_pages(const SnapshotDescriptor& d) {
    require(bool(d.id) && d.epoch && d.epoch <= revision_limit && d.sequence <= revision_limit &&
            d.bytes && d.bytes <= snapshot_limit, Error::InvalidRequest);
    return (d.bytes + snapshot_page_data - 1) / snapshot_page_data;
}
std::vector<std::uint8_t> encode_snapshot_page(const SnapshotData& data, std::size_t page) {
    const auto& d = data.descriptor; auto count = snapshot_pages(d);
    require(data.bytes.size() == d.bytes && page < count, Error::InvalidRequest);
    auto start = page * snapshot_page_data, size = std::min(snapshot_page_data, data.bytes.size() - start);
    Writer w; w.bytes.reserve(snapshot_page_header + size + 8);
    w.put(0x31505341, 4); w.id(d.id); w.put(d.epoch, 8); w.put(d.sequence, 8);
    w.put(page, 2); w.put(count, 2); w.put(d.bytes, 4);
    w.bytes.insert(w.bytes.end(), data.bytes.begin() + start, data.bytes.begin() + start + size);
    w.put(checkpoint_wire::checksum(w.bytes, w.bytes.size()), 8);
    return std::move(w.bytes);
}
}
