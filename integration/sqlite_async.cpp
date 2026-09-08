#include "sqlite_scenario.hpp"
#include "sqlite_backup.hpp"
#include "async_store.hpp"

void sqlite_async(const std::filesystem::path& path) {
    auto seed = sqlite_seed(); auto request = split_request(); Result first;
    for (int run = 0; run < 2; ++run) {
        auto driver = std::make_unique<AsyncStore>([path] { return std::make_unique<SQLiteStore>(path); }, seed);
        auto* worker = driver.get();
        eventually([&] { return worker->ready(); });
        DurableInventory world(std::move(driver), seed);
        auto before = world.snapshot();
        auto result = world.apply(request, access(world));
        if (run == 0) {
            CHECK(result.code == Error::Pending && world.snapshot() == before);
            eventually([&] { result = world.resolve(); return result.code != Error::Pending; });
            first = result;
        }
        CHECK(result.applied() && result.sequence == 1 && result.created == first.created);
        CHECK(world.snapshot()->items.at(id(100)).quantity == 13);
        Result closed;
        eventually([&] { closed = world.close(); return closed.code != Error::Pending; });
        CHECK(closed.applied());
        auto directory = path; directory += ".backups";
        auto backups = sq::backup_files(directory);
        CHECK(backups.size() == static_cast<unsigned>(run + 1));
        CHECK(sq::checked_backup(backups.back()).checkpoint.world == *world.snapshot());
        { SQLiteStore unlocked(path); } // Worker released the session lock before close returned Ok.
    }
}
