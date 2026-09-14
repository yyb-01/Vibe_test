#pragma once
#include "world.hpp"
#include <filesystem>

namespace astra {
// Offline operation. Publishes a verified, independent save without overwriting.
// Returns the restored commit sequence; subsequent opening acquires a new epoch.
std::uint64_t restore_sqlite_backup(const std::filesystem::path& backup,
    const std::filesystem::path& destination, const Catalog& expectedCatalog);
}
