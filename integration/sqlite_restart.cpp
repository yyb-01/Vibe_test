#include "sqlite_scenario.hpp"

void sqlite_restart(const std::filesystem::path& path) {
    Result saved; std::uint64_t epoch{};
    auto request = split_request();
    Request invalid;
    {
        auto first = open_world(path); epoch = first.epoch();
        rejects([&] { auto second = open_world(path.parent_path() / "." / path.filename()); }, Error::Busy);
        saved = first.apply(request, access(first));
        CHECK(saved.applied() && saved.sequence == 1 && saved.created.hi == 2);
        CHECK(first.apply(request, access(first)).created == saved.created);
        invalid = {{88, 2}, 2, Operation::Move,
            {move(*first.snapshot(), id(100), id(20), UINT16_MAX)}, 1, 99};
        CHECK(first.apply(invalid, access(first)).code == Error::InvalidPlacement);
    }
    {
        auto second = open_world(path);
        CHECK(second.epoch() == epoch + 1);
        CHECK(second.snapshot()->items.at(id(100)).quantity == 13);
        auto replay = second.apply(request, access(second));
        CHECK(replay.applied() && replay.created == saved.created && replay.sequence == 1);
        CHECK(second.apply(invalid, access(second)).code == Error::InvalidPlacement);
        auto changed = request; changed.moves[0].quantity = 6;
        CHECK(second.apply(changed, access(second)).code == Error::IdempotencyMismatch);
        auto old = access(second); old.epoch = epoch;
        CHECK(second.apply(request, old).code == Error::EpochMismatch);
        auto part = move(*second.snapshot(), id(100), id(20), 5); part.quantity = 1;
        Request next{{88, 3}, 3, Operation::Split, {part}, 1, 99};
        auto made = second.apply(next, access(second));
        CHECK(made.applied() && made.created.hi > saved.created.hi);
    }
    SQLiteStore store(path); auto loaded = store.acquire(sqlite_seed());
    CHECK(loaded.version == 3 && loaded.checkpoint.world.items.at(id(100)).quantity == 12);
    sq::Connection db(path); sq::configure(db);
    CHECK(sq::value(db, "PRAGMA journal_mode", "wal"));
    CHECK(sq::value(db, "PRAGMA synchronous", "2"));
    CHECK(sq::value(db, "PRAGMA foreign_keys", "1"));
    CHECK(sq::value(db, "PRAGMA integrity_check", "ok"));
}
