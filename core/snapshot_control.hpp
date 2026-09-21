#pragma once
#include "snapshot.hpp"
#include "packet.hpp"

namespace astra {
struct SnapshotOffer {
    std::uint64_t lease{};
    SnapshotDescriptor descriptor;
    std::set<Id> roots;
    bool operator==(const SnapshotOffer&) const = default;
};
std::vector<std::uint8_t> encode_snapshot_request(std::uint64_t epoch);
void decode_snapshot_request(const std::vector<std::uint8_t>&, std::uint64_t epoch);
std::vector<std::uint8_t> encode_snapshot_offer(const SnapshotOffer&);
SnapshotOffer decode_snapshot_offer(const std::vector<std::uint8_t>&, std::uint64_t epoch);
}
