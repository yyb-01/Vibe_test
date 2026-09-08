#include "sqlite_scenario.hpp"

void sqlite_rejections(const std::filesystem::path& dir) {
    { auto world = open_world(dir / u8"한글 월드.db"); }
    { auto world = open_world(dir / u8"한글 월드.db"); CHECK(world.epoch() == 3); }
    auto path = dir / "catalog.db";
    { auto world = open_world(path); }
    auto changed = sqlite_seed(); changed.catalog.at(1).massG++;
    validate(changed.catalog, changed.world);
    rejects([&] { SQLiteStore store(path); (void)store.acquire(changed); }, Error::Incompatible);
    { auto world = open_world(path); CHECK(world.epoch() == 3); }
    {
        sq::Connection db(path);
        db.exec("PRAGMA user_version=2");
    }
    rejects([&] { auto world = open_world(path); }, Error::Incompatible);
    {
        sq::Connection db(path);
        db.exec("PRAGMA user_version=1; UPDATE world SET checkpoint=zeroblob(76)");
    }
    rejects([&] { auto world = open_world(path); }, Error::InvalidState);
    auto foreign = dir / "foreign.db";
    { sq::Connection db(foreign); db.exec("CREATE TABLE unrelated(value TEXT)"); }
    rejects([&] { auto world = open_world(foreign); }, Error::Incompatible);
    auto overflow = sqlite_seed(); overflow.epoch = revision_limit;
    rejects([&] { SQLiteStore store(dir / "overflow.db"); (void)store.acquire(overflow); }, Error::LimitExceeded);
    { auto world = open_world(dir / "overflow.db"); CHECK(world.epoch() == 2); }
    auto occupied = sqlite_seed();
    occupied.world.items.emplace(Id{90, 1}, ItemState{});
    auto& dead = occupied.world.items.at({90, 1});
    dead.id = {90, 1}; dead.defId = 1; dead.quantity = 0; dead.flags = deleted;
    SQLiteStore store(dir / "origin.db");
    CHECK(store.acquire(occupied).checkpoint.origin == 91);
}
