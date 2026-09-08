#include "sqlite.hpp"
#include "sqlite_db.hpp"
#include <algorithm>

namespace astra {
SQLiteStore::SQLiteStore(const std::filesystem::path& path)
    : path_(world_path(path)), lock_(std::make_unique<WorldLock>(path_)) {}
StoredWorld SQLiteStore::acquire(const Checkpoint& seed) {
    require(lock_ && !epoch_, Error::InvalidState);
    validate_checkpoint(seed);
    sq::Connection db(path_);
    sq::configure(db);
    require(sq::value(db, "PRAGMA quick_check", "ok"), Error::InvalidState);
    db.exec("BEGIN IMMEDIATE");
    if (sq::value(db, "PRAGMA user_version", "0")) {
        require(sq::value(db, "PRAGMA application_id", "0") &&
                sq::value(db, "SELECT count(*) FROM sqlite_master", "0"), Error::Incompatible);
        db.exec("CREATE TABLE world(singleton INTEGER PRIMARY KEY CHECK(singleton=1),"
                "version INTEGER NOT NULL CHECK(version>=0),"
                "checkpoint BLOB NOT NULL CHECK(length(checkpoint) BETWEEN 76 AND 100663296)) STRICT;"
                "PRAGMA application_id=1095976018; PRAGMA user_version=1");
        sq::write(db, seed.requests.size(), encode_checkpoint(seed));
    }
    auto loaded = sq::load(db);
    auto& c = loaded.checkpoint;
    require(c.catalog == seed.catalog, Error::Incompatible);
    auto origin = c.origin;
    for (const auto& [id, item] : c.world.items) { (void)item; origin = std::max(origin, id.hi); }
    for (const auto& [id, container] : c.world.containers) { (void)container; origin = std::max(origin, id.hi); }
    require(c.epoch < revision_limit && origin < revision_limit, Error::LimitExceeded);
    ++c.epoch; c.origin = origin + 1; c.nextId = c.nextEvent = 1;
    sq::write(db, loaded.version, encode_checkpoint(c));
    db.exec("COMMIT"); epoch_ = c.epoch;
    return loaded;
}
StoredWorld SQLiteStore::inspect() {
    require(lock_ && epoch_ != 0, Error::InvalidState);
    sq::Connection db(path_); sq::configure(db);
    db.exec("BEGIN IMMEDIATE");
    auto loaded = sq::load(db);
    db.exec("COMMIT");
    return loaded;
}
}
