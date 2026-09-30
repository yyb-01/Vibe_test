#pragma once
#include "chamber.hpp"

namespace astra {
// Owned Slot: socketId orders homogeneous item stacks; height limits total rounds.
// ponytail: reuse the existing 32-slot bound; extend the representation for larger magazine definitions.
struct Magazine { Id container, nextRound; std::uint32_t rounds{}; };
void validate_magazines(const Catalog&, const World&);
Magazine magazine_state(const World&, Id magazine);
// Host helper for a magazine mounted directly in a weapon-owned ordinary Slot.
// Uses the first run's round and the existing atomic Move/Split; family/profile validation is the caller's job.
Request feed_request(const World&, Id weapon, Id magazine, Id requestId,
                     std::uint64_t actionSeq, std::uint64_t lease);
}
