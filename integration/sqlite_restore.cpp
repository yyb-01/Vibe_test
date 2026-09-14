#include "sqlite_scenario.hpp"
#include "sqlite_backup.hpp"
#include "sqlite_restore.hpp"
#include <fstream>

void sqlite_restore(const std::filesystem::path& dir) {
    auto original = dir / "restore-original.db", destination = dir / "restore-new.db";
    auto bytes = [](const auto& path) {
        std::ifstream file(path, std::ios::binary);
        CHECK(file.good());
        return std::string(std::istreambuf_iterator<char>(file), {});
    };
    { auto world = open_world(original);
      CHECK(world.apply(split_request(), access(world)).applied()); CHECK(world.close().applied()); }
    auto backup = sq::backup_files(original.string() + ".backups").back();
    auto originalBytes = bytes(original), backupBytes = bytes(backup);
    auto saved = sq::checked_backup(backup);
    auto restore = [&] { return restore_sqlite_backup(backup, destination, catalog()); };
    rejects([&] { restore_sqlite_backup(backup, original, catalog()); }, Error::InvalidState);
    rejects([&] { restore_sqlite_backup(backup, backup, catalog()); }, Error::InvalidState);
    rejects([&] { restore_sqlite_backup(backup, backup.parent_path() / "new.db", catalog()); }, Error::InvalidState);
    { WorldLock lock(backup); rejects(restore, Error::Busy); }
    { WorldLock lock(destination); rejects(restore, Error::Busy); }
    auto different = catalog(); ++different.at(1).massG;
    rejects([&] { restore_sqlite_backup(backup, destination, different); }, Error::Incompatible);
    auto journal = destination; journal += "-wal";
    std::ofstream(journal) << "preserve";
    rejects(restore, Error::InvalidState);
    CHECK(bytes(journal) == "preserve" && !std::filesystem::exists(destination));
    CHECK(std::filesystem::remove(journal));
    CHECK(restore() == 1);
    CHECK(encode_checkpoint(sq::checked_backup(destination).checkpoint) == encode_checkpoint(saved.checkpoint));
    rejects(restore, Error::InvalidState);
    { auto world = open_world(destination);
      CHECK(world.epoch() == saved.checkpoint.epoch + 1);
      CHECK(world.next_action_sequence({77, 1}) == 2);
      auto replay = world.apply(split_request(), access(world));
      CHECK(replay.applied() && replay.sequence == 1);
      Request moveIt{{88, 2}, 2, Operation::Move, {move(*world.snapshot(), replay.created, id(20), 5)}, 0, 99};
      CHECK(world.apply(moveIt, access(world)).applied()); CHECK(world.close().applied()); }
    { auto world = open_world(destination); CHECK(world.next_action_sequence({77, 1}) == 3); }
    CHECK(bytes(original) == originalBytes && bytes(backup) == backupBytes);
    auto bad = dir / "restore-bad.db";
    std::filesystem::copy_file(backup, bad);
    { sq::Connection db(bad); db.exec("UPDATE world SET checkpoint=zeroblob(76)"); }
    rejects([&] { restore_sqlite_backup(bad, dir / "not-created.db", catalog()); }, Error::InvalidState);
    CHECK(!std::filesystem::exists(dir / "not-created.db"));
}
