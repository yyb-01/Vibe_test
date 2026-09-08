#include "sqlite_scenario.hpp"
#include "sqlite_backup.hpp"

void sqlite_backup_failures(const std::filesystem::path& path) {
    auto directory = path; directory += ".backups";
    for (int i = 0; i < 3; ++i) { auto world = open_world(path); CHECK(world.close().applied()); }
    auto previous = sq::backup_files(directory);
    auto world = open_world(path);
    CHECK(world.apply(split_request(), access(world)).applied());
    auto epoch = std::to_string(world.epoch());
    auto final = directory / ("backup-" + std::string(20 - epoch.size(), '0') + epoch + ".sqlite3");
    std::filesystem::create_directory(final); // Block publication without changing older backups.
    CHECK(world.close().code == Error::StorageUnavailable);
    CHECK(sq::backup_files(directory) == previous);
    for (const auto& file : previous) CHECK(sq::checked_backup(file).version == 0);
    rejects([&] { auto second = open_world(path); }, Error::Busy);
    CHECK(world.apply(split_request(), access(world)).code == Error::Busy);
    CHECK(std::filesystem::remove(final));
#ifdef _WIN32
    auto handle = CreateFileW(previous.front().c_str(), GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    CHECK(handle != INVALID_HANDLE_VALUE);
    auto failed = world.close(); // New backup is published; deleting the oldest must fail.
    CloseHandle(handle);
    CHECK(failed.code == Error::StorageUnavailable);
    CHECK(sq::backup_files(directory).size() == 4);
    CHECK(sq::checked_backup(final).version == 1);
    rejects([&] { auto second = open_world(path); }, Error::Busy);
#endif
    CHECK(world.close().applied()); // Reuse verified publication and retry pruning.
    CHECK(sq::backup_files(directory).size() == 3);
    CHECK(!std::filesystem::exists(previous.front()));
    CHECK(sq::checked_backup(final).version == 1);
    auto reopened = open_world(path);
    CHECK(reopened.snapshot()->items.at(id(100)).quantity == 13);
}
