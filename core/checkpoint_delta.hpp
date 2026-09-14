#pragma once
#include "checkpoint.hpp"

namespace astra {
struct CheckpointDelta {
    WriteSet changes;
    std::uint64_t origin{}, sequence{}, nextId{}, nextEvent{};
};
SavedRequest delta_record(const CheckpointDelta&);
// Mutates a private staging checkpoint; discard it if validation fails.
void apply_checkpoint_delta(Checkpoint&, const CheckpointDelta&);
std::vector<std::uint8_t> encode_delta(const CheckpointDelta&);
CheckpointDelta decode_delta(const std::vector<std::uint8_t>&);
}
