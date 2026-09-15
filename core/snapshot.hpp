#pragma once
#include "world.hpp"
#include "transaction.hpp"

namespace astra {
inline constexpr std::size_t snapshot_limit = 2 * 1024 * 1024;
inline constexpr std::size_t snapshot_page_limit = 65536, snapshot_page_header = 44;
inline constexpr std::size_t snapshot_page_data = snapshot_page_limit - snapshot_page_header - 8;
struct SnapshotDescriptor {
    Id id;
    std::uint64_t epoch{}, sequence{};
    std::uint32_t bytes{};
    bool operator==(const SnapshotDescriptor&) const = default;
};
struct SnapshotData {
    SnapshotDescriptor descriptor;
    std::vector<std::uint8_t> bytes;
};
std::vector<std::uint8_t> encode_view(const RootSnapshot&);
World decode_view(const std::vector<std::uint8_t>&, const Catalog&);
std::size_t snapshot_pages(const SnapshotDescriptor&);
std::vector<std::uint8_t> encode_snapshot_page(const SnapshotData&, std::size_t page);
// One instance per authenticated connection. Never replaces an incomplete stream implicitly.
class SnapshotAssembly {
public:
    explicit SnapshotAssembly(SnapshotDescriptor);
    void receive(const std::vector<std::uint8_t>& frame);
    bool complete() const;
    const std::vector<std::uint8_t>& bytes() const;
private:
    SnapshotDescriptor descriptor_;
    std::vector<std::uint8_t> data_;
    std::uint64_t received_{};
};
}
