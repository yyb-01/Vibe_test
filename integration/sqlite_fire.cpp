#include "sqlite_fault_store.hpp"
#include "sqlite_backup.hpp"
#include "../tests/fire_scenario.hpp"

void sqlite_fire(const std::filesystem::path& path) {
    auto request = shot_request(fire_checkpoint().world);
    {
        auto driver = std::make_unique<LostReply>(path); auto* fault = driver.get();
        DurableInventory world(std::move(driver), fire_checkpoint());
        auto allowed = approve_fire(request, shot_authority(), access(world));
        auto before = world.snapshot();
        {
            sq::Connection db(path);
            db.exec("CREATE TRIGGER fail_fire AFTER UPDATE ON world BEGIN SELECT RAISE(ABORT,'injected'); END");
            CHECK(world.apply(request, allowed).code == Error::StorageUnavailable);
            CHECK(world.snapshot() == before && fault->real.inspect().checkpoint.requests.empty());
            db.exec("DROP TRIGGER fail_fire");
        }
        CHECK(world.apply(request, allowed).code == Error::Pending && world.snapshot() == before);
        CHECK(world.recorded_fires().empty());
        auto saved = fault->real.inspect();
        CHECK(saved.checkpoint.world.items.at(id(100)).quantity == 0);
        CHECK(saved.checkpoint.world.items.at(id(104)).durability == 65530);
        CHECK(saved.checkpoint.requests.size() == 1 && decode(saved.checkpoint.requests[0].payload).shot == request.shot);
        CHECK(world.resolve().applied());
        CHECK(world.apply(request, allowed).sequence == 1);
    }
    {
        DurableInventory recovered(std::make_unique<SQLiteStore>(path), fire_checkpoint());
        auto original = recovered.recorded_fire(access(recovered).account, request.shot->intent.fireSeq);
        CHECK(original && encode(*original) == encode(request));
        auto history = recovered.recorded_fires();
        CHECK(history.size() == 1 && history[0].account == access(recovered).account &&
              history[0].weapon == id(104) && history[0].shot == *request.shot && history[0].sequence == 1);
        CHECK(recovered.apply(request, access(recovered)).sequence == 1);
        CHECK(recovered.snapshot()->items.at(id(100)).quantity == 0);
        CHECK(recovered.snapshot()->items.at(id(104)).durability == 65530);
        CHECK(recovered.close().applied());
        auto directory = path; directory += ".backups";
        auto files = sq::backup_files(directory); CHECK(files.size() == 1);
        auto backup = sq::checked_backup(files.back());
        CHECK(backup.checkpoint.world == *recovered.snapshot());
        CHECK(decode(backup.checkpoint.requests[0].payload).shot == request.shot);
    }
}
