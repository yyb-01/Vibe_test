#include "sqlite_backup.hpp"
#include "world_lock.hpp"
#include <chrono>

namespace astra::sq {
void copy_backup(Connection& source, const StoredWorld& current, const std::filesystem::path& final) {
    auto same = [&](const std::filesystem::path& path) {
        auto saved = checked_backup(path);
        require(saved.version == current.version &&
                encode_checkpoint(saved.checkpoint) == encode_checkpoint(current.checkpoint), Error::InvalidState);
    };
    if (std::filesystem::exists(final)) { same(final); return; } // Retry after publication/pruning failure.
    auto temporary = final;
    temporary += "." + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()) + ".tmp";
    require(!std::filesystem::exists(temporary), Error::StorageUnavailable);
    try {
        {
            Connection target(temporary);
            target.exec("PRAGMA synchronous=FULL");
            require(value(target, "PRAGMA synchronous", "2") &&
                    value(target, "PRAGMA journal_mode=DELETE", "delete"), Error::StorageUnavailable);
            auto backup = sqlite3_backup_init(target.get(), "main", source.get(), "main");
            require(backup != nullptr, Error::StorageUnavailable);
            auto step = sqlite3_backup_step(backup, -1);
            auto finish = sqlite3_backup_finish(backup);
            require(step == SQLITE_DONE && finish == SQLITE_OK, Error::StorageUnavailable);
            require(value(target, "PRAGMA journal_mode=DELETE", "delete"), Error::StorageUnavailable);
        }
        same(temporary);
#ifdef _WIN32
        require(MoveFileExW(temporary.c_str(), final.c_str(), MOVEFILE_WRITE_THROUGH), Error::StorageUnavailable);
#else
        std::filesystem::rename(temporary, final);
        int directory = open(final.parent_path().c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        require(directory >= 0, Error::StorageUnavailable);
        auto synced = fsync(directory); close(directory);
        require(synced == 0, Error::StorageUnavailable);
#endif
    } catch (...) {
        std::error_code ignored;
        std::filesystem::remove(temporary, ignored);
        throw;
    }
}
}
