#pragma once
#include "write_set.hpp"

namespace astra {
struct SavedRequest {
    Id account, requestId;
    std::uint64_t actionSeq{};
    std::vector<std::uint8_t> payload;
    Result result;
};
struct Checkpoint {
    Catalog catalog;
    World world;
    std::uint64_t epoch{}, origin{}, sequence{}, nextId{1}, nextEvent{1};
    std::vector<SavedRequest> requests;
};
inline constexpr std::size_t checkpoint_byte_limit = 96 * 1024 * 1024;
void validate_checkpoint(const Checkpoint&);
std::vector<std::uint8_t> encode_checkpoint(const Checkpoint&);
Checkpoint decode_checkpoint(const std::vector<std::uint8_t>&);
}
