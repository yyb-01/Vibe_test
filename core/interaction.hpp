#pragma once
#include "transaction_budget.hpp"
#include "transaction.hpp"

namespace astra {
// Trusted, fresh authority observations from the bound Pawn; never client fields.
struct RootObservation {
    Id root;
    double distanceM{};
    bool lineOfSight{}, permitted{};
};
struct InteractionState {
    Id pawn;
    bool alive{}, canInteract{};
    std::vector<RootObservation> roots;
};
inline constexpr auto interaction_lease_lifetime = std::chrono::seconds(5);
struct InteractionLease {
    std::uint64_t token{};
    TransactionBudget::Clock::time_point issued{}, expires{};
    std::set<Id> roots;
};
std::set<Id> interaction_roots(const InteractionState&, Id expectedPawn);
}
