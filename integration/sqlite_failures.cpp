#include "sqlite_fault_store.hpp"
void sqlite_failures(const std::filesystem::path& path) {
    auto driver = std::make_unique<LostReply>(path); auto* fault = driver.get();
    DurableInventory inventory(std::move(driver), sqlite_seed());
    auto original = inventory.snapshot(); auto request = split_request();
    {
        sq::Connection db(path);
        db.exec("CREATE TRIGGER fail_save AFTER UPDATE ON world BEGIN SELECT RAISE(ABORT,'injected'); END");
        CHECK(inventory.apply(request, access(inventory)).code == Error::StorageUnavailable);
        CHECK(inventory.snapshot() == original && fault->real.inspect().version == 0);
        db.exec("DROP TRIGGER fail_save");
    }
    fault->before = true;
    CHECK(inventory.apply(request, access(inventory)).code == Error::Pending);
    CHECK(inventory.resolve().code == Error::StorageUnavailable);
    fault->before = false;
    CHECK(inventory.apply(request, access(inventory)).code == Error::Pending);
    CHECK(inventory.snapshot() == original && fault->real.inspect().version == 1);
    auto other = request; other.id = {88, 2};
    CHECK(inventory.apply(other, access(inventory)).code == Error::Busy);
    other = request; other.moves[0].quantity = 6;
    CHECK(inventory.apply(other, access(inventory)).code == Error::IdempotencyMismatch);
    fault->unreadable = true;
    CHECK(inventory.resolve().code == Error::Pending);
    fault->unreadable = false;
    auto result = inventory.resolve();
    CHECK(result.applied() && result.sequence == 1);
    CHECK(inventory.apply(request, access(inventory)).created == result.created);
    CHECK(inventory.snapshot()->items.at(id(100)).quantity == 13);
    auto loaded = fault->real.inspect();
    CHECK(fault->real.save(0, loaded.checkpoint, loaded.checkpoint.requests.back()) == SaveOutcome::Committed);
    CHECK(fault->real.save(2, loaded.checkpoint, loaded.checkpoint.requests.back()) == SaveOutcome::Fenced);
}
