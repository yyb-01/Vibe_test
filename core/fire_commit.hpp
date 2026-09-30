#pragma once
#include "transaction.hpp"
#include "fire_validation.hpp"

namespace astra {
// Host only: request item IDs, launch data and profiles must come from authority, not the client.
// Call under the gameplay owner's admission boundary; Inventory rechecks row revisions/reservations.
Access approve_fire(const Request&, const FireAuthority&, Access);
// Applied SavedRequest.result.sequence is the world-local shotId. No effect before durable success.
}
