#include "sqlite_scenario.hpp"
#include "../tests/fire_scenario.hpp"
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <thread>

void sqlite_fire(const std::filesystem::path&);
void sqlite_magazine(const std::filesystem::path&);

int main(int argc, char** argv) {
    if (argc < 3) return 2;
    std::string mode = argv[1];
    bool firing = mode.starts_with("fire-");
    if (firing) mode = mode.substr(5);
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
            sqlite_restore(path);
            sqlite_fire(path / "fire.db");
            sqlite_magazine(path / "magazine.db");
            std::cout << "PASS SQLite magazine: rollback, lost ACK, ordered feed, restart\n";
            std::cout << "PASS SQLite fire: ammo, durability, event, rollback, lost ACK, replay\n";
            std::cout << "PASS SQLite restore: new save, replay, locks, no overwrite, corruption\n";
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
            SQLiteStore store(path); auto loaded = store.acquire(firing ? fire_checkpoint() : sqlite_seed());
            Inventory memory(loaded.checkpoint);
            auto request = firing ? shot_request(*memory.snapshot()) : split_request();
            Access allowed{{77,1}, loaded.checkpoint.epoch, 99, {id(10), id(20), id(30)}};
            if (firing) allowed = approve_fire(request, shot_authority(), allowed);
            auto prepared = memory.prepare(request, allowed);
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
            DurableInventory world(std::make_unique<SQLiteStore>(path), firing ? fire_checkpoint() : sqlite_seed());
            CHECK(world.snapshot()->items.at(id(100)).quantity == (firing ? (mode == "empty" ? 1u : 0u) : (mode == "empty" ? 20u : 13u)));
            if (firing) CHECK(world.snapshot()->items.at(id(104)).durability == (mode == "empty" ? 65535 : 65530));
            if (mode == "recover") {
                auto request = firing ? shot_request(fire_checkpoint().world) : split_request();
                auto r = world.apply(request, access(world));
                CHECK(r.applied() && r.sequence == 1);
                CHECK(world.snapshot()->items.at(id(100)).quantity == (firing ? 0u : 13u));
            }
        } else return 2;
        std::cout << "PASS SQLite " << mode << '\n';
        return 0;
    } catch (const Violation& e) { std::cerr << name(e.code) << '\n'; }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; }
    return 1;
}
