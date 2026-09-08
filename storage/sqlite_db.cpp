#include "sqlite_db.hpp"

namespace astra::sq {
void configure(Connection& db) {
    require(sqlite3_libversion_number() == 3053004, Error::Incompatible);
    require(value(db, "PRAGMA journal_mode=WAL", "wal"), Error::StorageUnavailable);
    db.exec("PRAGMA synchronous=FULL; PRAGMA foreign_keys=ON; PRAGMA trusted_schema=OFF");
    require(value(db, "PRAGMA synchronous", "2") && value(db, "PRAGMA foreign_keys", "1"),
            Error::StorageUnavailable);
}
StoredWorld load(Connection& db) {
    require(value(db, "PRAGMA application_id", "1095976018") &&
            value(db, "PRAGMA user_version", "1"), Error::Incompatible);
    Statement query(db, "SELECT version, checkpoint FROM world WHERE singleton=1");
    require(query.row(), Error::InvalidState);
    auto version = query.number(0);
    auto length = sqlite3_column_bytes(query.get(), 1);
    require(sqlite3_column_type(query.get(), 1) == SQLITE_BLOB && length >= 76 &&
            static_cast<std::size_t>(length) <= checkpoint_byte_limit, Error::InvalidState);
    auto data = static_cast<const std::uint8_t*>(sqlite3_column_blob(query.get(), 1));
    require(data != nullptr, Error::StorageUnavailable);
    auto checkpoint = decode_checkpoint({data, data + length});
    require(version == checkpoint.requests.size() && !query.row(), Error::InvalidState);
    return {std::move(checkpoint), version};
}
void write(Connection& db, std::uint64_t version, const std::vector<std::uint8_t>& bytes) {
    // ponytail: full checkpoint per commit; use row deltas when measured cost requires it.
    // The checkpoint contains state AND all request results in the same atomic row.
    Statement update(db, "INSERT INTO world VALUES(1,?1,?2) ON CONFLICT(singleton) "
                         "DO UPDATE SET version=excluded.version, checkpoint=excluded.checkpoint");
    update.number(1, version); update.blob(2, bytes);
    require(!update.row(), Error::InvalidState);
}
}
