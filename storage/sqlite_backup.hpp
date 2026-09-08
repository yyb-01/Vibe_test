#pragma once
#include "sqlite_db.hpp"
#include <algorithm>

namespace astra::sq {
inline StoredWorld checked_backup(const std::filesystem::path& path) {
    Connection db(path, true);
    require(value(db, "PRAGMA integrity_check", "ok"), Error::InvalidState);
    return load(db);
}
inline std::vector<std::filesystem::path> backup_files(const std::filesystem::path& directory) {
    std::vector<std::filesystem::path> paths;
    for (const auto& entry : std::filesystem::directory_iterator(directory)) {
        auto name = entry.path().filename().string();
        if (entry.is_symlink() || !entry.is_regular_file() || name.size() != 35 ||
            !name.starts_with("backup-") || !name.ends_with(".sqlite3")) continue;
        if (std::all_of(name.begin() + 7, name.begin() + 27, [](char c) { return c >= '0' && c <= '9'; }))
            paths.push_back(entry.path());
    }
    std::sort(paths.begin(), paths.end());
    return paths;
}
void copy_backup(Connection&, const StoredWorld&, const std::filesystem::path&);
}
