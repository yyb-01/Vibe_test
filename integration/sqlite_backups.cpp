#include "sqlite_scenario.hpp"
#include "sqlite_backup.hpp"
#include <fstream>

void sqlite_backups(const std::filesystem::path& path) {
    auto directory = path; directory += ".backups";
    Result made;
    for (unsigned i = 0; i < 5; ++i) {
        auto world = open_world(path);
        // Hold a connection so committed WAL pages remain during backup.
        sq::Connection reader(path); sq::configure(reader);
        made = world.apply(split_request(), access(world));
        CHECK(made.applied() && made.sequence == 1);
        CHECK(world.close().applied());
        CHECK(world.close().applied());
        CHECK(world.apply(split_request(), access(world)).code == Error::Busy);
        auto files = sq::backup_files(directory);
        CHECK(files.size() == std::min(i + 1, 3u));
        auto saved = sq::checked_backup(files.back());
        CHECK(saved.version == 1 && saved.checkpoint.epoch == world.epoch());
        CHECK(saved.checkpoint.world == *world.snapshot());
        Inventory restored(saved.checkpoint);
        auto replay = restored.apply(split_request(), access(world));
        CHECK(replay.applied() && replay.created == made.created && replay.sequence == 1);
        CHECK(restored.snapshot()->items.at(id(100)).quantity == 13);
    }
    // Damaged published backups and crash leftovers are preserved, not counted as healthy.
    auto files = sq::backup_files(directory);
    std::ofstream(files.front(), std::ios::binary | std::ios::trunc) << "damaged";
    std::ofstream(directory / "interrupted.tmp") << "unfinished";
    auto world = open_world(path);
    CHECK(world.close().applied());
    CHECK(sq::backup_files(directory).size() == 4);
    CHECK(std::filesystem::exists(files.front()));
    CHECK(std::filesystem::exists(directory / "interrupted.tmp"));
}
