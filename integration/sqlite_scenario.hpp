#pragma once
#include "sqlite.hpp"
#include "sqlite_db.hpp"
#include "../tests/scenario.hpp"

inline Checkpoint sqlite_seed() { return Inventory(catalog(), seed(), 1, 1).checkpoint(); }
inline Access access(const DurableInventory& inventory) {
    return {{77, 1}, inventory.epoch(), 99, {id(10), id(20), id(30)}};
}
inline Request split_request() {
    auto c = sqlite_seed();
    auto part = move(c.world, id(100), id(20)); part.quantity = 7;
    return {{88, 1}, 1, Operation::Split, {part}, 0, 99};
}
inline DurableInventory open_world(const std::filesystem::path& path) {
    return DurableInventory(std::make_unique<SQLiteStore>(path), sqlite_seed());
}
void sqlite_restart(const std::filesystem::path&);
void sqlite_failures(const std::filesystem::path&);
void sqlite_rejections(const std::filesystem::path&);
void sqlite_backups(const std::filesystem::path&);
void sqlite_shutdown(const std::filesystem::path&);
void sqlite_backup_failures(const std::filesystem::path&);
void sqlite_async(const std::filesystem::path&);
