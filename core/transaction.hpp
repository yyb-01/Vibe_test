#pragma once
#include "types.hpp"
#include "error.hpp"
#include <set>
#include <vector>

namespace astra {
enum class Operation : std::uint8_t { Move, Swap, Split, Merge, Drop, Pickup };
struct MoveEntry {
    Id item, source, target;
    std::uint64_t itemRev{}, sourceRev{}, targetRev{};
    std::uint32_t quantity{}, socketId{};
    std::uint16_t x{}, y{};
    std::uint8_t rotation{};
};
struct Request {
    Id id;
    std::uint64_t actionSeq{};
    Operation operation{};
    std::vector<MoveEntry> moves;
    std::uint64_t baseline{}, interactionLease{};
};
// Supplied by the authoritative host, never decoded from a client's packet.
struct Access {
    Id account;
    std::uint64_t epoch{}, interactionLease{};
    std::set<Id> roots;
};
struct Result {
    Error code{Error::Ok};
    std::uint64_t sequence{};
    Id created;
    bool applied() const { return code == Error::Ok; }
};
std::vector<std::uint8_t> encode(const Request&);
Request decode(const std::vector<std::uint8_t>&);
}
