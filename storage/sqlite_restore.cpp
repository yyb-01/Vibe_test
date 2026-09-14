#include "sqlite_restore.hpp"
#include "sqlite_backup.hpp"
#include "world_lock.hpp"
#include <cctype>

namespace astra {
namespace {
void absent(const std::filesystem::path& path) {
    // symlink_status also rejects dangling links at a proposed output path.
    require(!std::filesystem::exists(std::filesystem::symlink_status(path)), Error::InvalidState);
}
void no_journals(const std::filesystem::path& path) {
    for (auto suffix : {"-wal", "-shm", "-journal"}) {
        auto sidecar = path; sidecar += suffix; absent(sidecar);
    }
}
}
std::uint64_t restore_sqlite_backup(const std::filesystem::path& backup,
    const std::filesystem::path& destination, const Catalog& expectedCatalog) {
    auto from = world_path(backup), to = world_path(destination);
    require(from != to && std::filesystem::is_regular_file(from), Error::InvalidState);
    for (const auto& part : to.parent_path()) {
        auto extension = part.extension().string();
        std::transform(extension.begin(), extension.end(), extension.begin(), [](unsigned char c) { return char(std::tolower(c)); });
        require(extension != ".backups", Error::InvalidState); // Never expose a restored save to backup pruning.
    }
    WorldLock sourceLock(from);
    no_journals(from);
    sq::Connection source(from, true);
    source.exec("BEGIN");
    require(sq::value(source, "PRAGMA journal_mode", "delete") &&
            sq::value(source, "PRAGMA integrity_check", "ok"), Error::InvalidState);
    auto saved = sq::load(source);
    require(saved.checkpoint.catalog == expectedCatalog, Error::Incompatible);
    // Refuse a valid but exhausted checkpoint that cannot start another session.
    auto origin = saved.checkpoint.origin;
    for (const auto& [id, item] : saved.checkpoint.world.items) { (void)item; origin = std::max(origin, id.hi); }
    for (const auto& [id, container] : saved.checkpoint.world.containers) { (void)container; origin = std::max(origin, id.hi); }
    require(saved.checkpoint.epoch < revision_limit && origin < revision_limit, Error::LimitExceeded);
    std::filesystem::create_directories(to.parent_path());
    WorldLock destinationLock(to);
    absent(to); no_journals(to);
    auto backups = to; backups += ".backups"; absent(backups);
    sq::copy_backup(source, saved, to);
    source.exec("COMMIT");
    return saved.checkpoint.sequence;
}
}
