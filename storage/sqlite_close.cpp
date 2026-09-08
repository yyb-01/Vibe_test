#include "sqlite.hpp"
#include "sqlite_backup.hpp"

namespace astra {
void SQLiteStore::close() {
    if (!lock_) return;
    require(epoch_ != 0, Error::InvalidState);
    {
        sq::Connection source(path_); sq::configure(source);
        source.exec("BEGIN"); // Pin a consistent read snapshot, including committed WAL pages.
        auto current = sq::load(source);
        require(current.checkpoint.epoch == epoch_, Error::EpochMismatch);
        auto directory = path_; directory += ".backups";
        std::filesystem::create_directory(directory);
        auto epoch = std::to_string(epoch_);
        auto final = directory / ("backup-" + std::string(20 - epoch.size(), '0') + epoch + ".sqlite3");
        sq::copy_backup(source, current, final);
        // Only prune after the new backup has been validated and published.
        auto files = sq::backup_files(directory);
        std::vector<std::filesystem::path> valid;
        for (const auto& file : files) {
            try { (void)sq::checked_backup(file); valid.push_back(file); }
            catch (const Violation&) { /* Preserve damaged or unreadable backups for diagnosis. */ }
        }
        while (valid.size() > 3) {
            require(std::filesystem::remove(valid.front()), Error::StorageUnavailable);
            valid.erase(valid.begin());
        }
        source.exec("COMMIT");
    }
    lock_.reset();
}
}
