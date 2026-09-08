#include "scenario.hpp"
#include "durable.hpp"

namespace {
class BudgetStore : public DurableStore {
    StoredWorld saved_;
public:
    bool limited{true};
    StoredWorld acquire(const Checkpoint& seed) override { saved_ = {seed, 0}; return saved_; }
    SaveOutcome save(std::uint64_t version, const Checkpoint& target, const SavedRequest&) override {
        if (limited) return SaveOutcome::Limited;
        saved_ = {target, version + 1}; return SaveOutcome::Committed;
    }
    StoredWorld inspect() override { return saved_; }
};
}
void async_budget_rollback() {
    Scenario source;
    auto store = std::make_unique<BudgetStore>(); auto* limit = store.get();
    DurableInventory inventory(std::move(store), source.inventory.checkpoint());
    auto part = move(*inventory.snapshot(), id(100), id(20)); part.quantity = 7;
    auto request = source.request(Operation::Split, {part});
    auto before = inventory.snapshot();
    CHECK(inventory.apply(request, source.access).code == Error::LimitExceeded);
    CHECK(inventory.snapshot() == before && limit->inspect().version == 0);
    limit->limited = false;
    auto retried = inventory.apply(request, source.access);
    CHECK(retried.applied() && retried.sequence == 1);
    CHECK(inventory.snapshot()->items.at(id(100)).quantity == 13);
}
