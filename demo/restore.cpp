#include "console.hpp"
#include <iostream>
#ifdef ASTRA_DEMO_SQLITE
#include "sqlite_restore.hpp"
#endif

void restore(const std::filesystem::path& backup, const std::filesystem::path& destination) {
#ifdef ASTRA_DEMO_SQLITE
    auto sequence = restore_sqlite_backup(backup, destination, catalog());
    std::cout << "Restored backup to a new save. Snapshot sequence=" << sequence << '\n'
              << "Progress after this snapshot is not included. The original save is preserved.\n";
#else
    (void)backup; (void)destination;
    throw std::runtime_error("SQLite support is unavailable. Run scripts/play.ps1 -RestoreBackup BACKUP -SavePath NEW_PATH.");
#endif
}
