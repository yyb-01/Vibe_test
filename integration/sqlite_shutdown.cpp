#include "sqlite_fault_store.hpp"
#include "sqlite_backup.hpp"

void sqlite_shutdown(const std::filesystem::path& path) {
    auto driver = std::make_unique<LostReply>(path); auto* fault = driver.get();
    DurableInventory world(std::move(driver), sqlite_seed());
    auto old = world.snapshot();
    CHECK(world.apply(split_request(), access(world)).code == Error::Pending);
    fault->unreadable = true;
    CHECK(world.close().code == Error::Pending);
    CHECK(world.snapshot() == old);
    CHECK(world.apply(split_request(), access(world)).code == Error::Busy);
    auto directory = path; directory += ".backups";
    CHECK(!std::filesystem::exists(directory));
    rejects([&] { auto second = open_world(path); }, Error::Busy);
    fault->unreadable = false;
    CHECK(world.close().applied());
    CHECK(world.snapshot()->items.at(id(100)).quantity == 13);
    CHECK(sq::backup_files(directory).size() == 1);
    { auto second = open_world(path); CHECK(second.snapshot()->items.at(id(100)).quantity == 13); }

    auto aborted = path; aborted += ".aborted";
    auto noWrite = std::make_unique<LostReply>(aborted); noWrite->before = true;
    DurableInventory rollback(std::move(noWrite), sqlite_seed());
    CHECK(rollback.apply(split_request(), access(rollback)).code == Error::Pending);
    CHECK(rollback.close().applied()); // Shutdown success does not ACK the aborted request.
    SQLiteStore verify(aborted); auto loaded = verify.acquire(sqlite_seed());
    CHECK(loaded.version == 0 && loaded.checkpoint.world.items.at(id(100)).quantity == 20);
}
