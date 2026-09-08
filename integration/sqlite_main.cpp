#include "sqlite_scenario.hpp"
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <thread>

int main(int argc, char** argv) {
    if (argc < 3) return 2;
    std::string mode = argv[1];
    auto path = std::filesystem::path(std::u8string(reinterpret_cast<const char8_t*>(argv[2])));
    try {
        if (mode == "suite") {
            sqlite_restart(path / "restart.db");
            sqlite_failures(path / "faults.db");
            sqlite_rejections(path);
            sqlite_backups(path / "backups.db");
            sqlite_shutdown(path / "shutdown.db");
            sqlite_backup_failures(path / "backup-failure.db");
            sqlite_async(path / "async.db");
            std::cout << "PASS SQLite async commit, restart, shutdown backup\n";
            std::cout << "PASS SQLite backup rotation, shutdown, backup failure retry\n";
        } else if (mode == "hold") {
            auto world = open_world(path);
            auto ready = path; ready += ".ready";
            std::ofstream(ready) << "ready";
            std::this_thread::sleep_for(std::chrono::seconds(30));
        } else if (mode == "locked") {
            rejects([&] { auto world = open_world(path); }, Error::Busy);
        } else if (mode == "crash-before" || mode == "crash-after") {
            SQLiteStore store(path); auto loaded = store.acquire(sqlite_seed());
            Inventory memory(loaded.checkpoint);
            auto prepared = memory.prepare(split_request(), {{77,1}, loaded.checkpoint.epoch, 99,
                {id(10), id(20), id(30)}});
            CHECK(prepared.changes);
            auto target = memory.checkpoint_after(prepared.changes);
            if (mode == "crash-before") {
                sq::Connection db(path); sq::configure(db);
                db.exec("PRAGMA cache_size=1; BEGIN IMMEDIATE");
                sq::write(db, loaded.version + 1, encode_checkpoint(target));
                sq::check(sqlite3_db_cacheflush(db.get()));
                std::_Exit(73);
            }
            CHECK(store.save(loaded.version, target, target.requests.back()) == SaveOutcome::Committed);
            std::_Exit(73); // Durable DB commit, before memory publication or ACK.
        } else if (mode == "empty" || mode == "recover") {
            auto world = open_world(path);
            CHECK(world.snapshot()->items.at(id(100)).quantity == (mode == "empty" ? 20u : 13u));
            if (mode == "recover") {
                auto r = world.apply(split_request(), access(world));
                CHECK(r.applied() && r.sequence == 1);
                CHECK(world.snapshot()->items.at(id(100)).quantity == 13);
            }
        } else return 2;
        std::cout << "PASS SQLite " << mode << '\n';
        return 0;
    } catch (const Violation& e) { std::cerr << name(e.code) << '\n'; }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; }
    return 1;
}
