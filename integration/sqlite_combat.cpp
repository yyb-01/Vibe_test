#include "sqlite_combat_fixture.hpp"

void sqlite_combat(const std::filesystem::path& path) {
    auto initial = fire_clock_seed(); auto input = shot_request(seed()).shot->intent;
    astra::ballistics::Atmosphere vacuum; vacuum.gravity = {};
    std::optional<ShotData> original;
    {
        DurableInventory inventory(std::make_unique<SQLiteStore>(path), initial);
        HostSession host(inventory, session_info(), {14, 1}, fixed_time);
        auto observation = combat_observation({77, 1}, {14, 1});
        {
            sq::Connection db(path);
            db.exec("CREATE TRIGGER fail_shot AFTER UPDATE ON world BEGIN SELECT RAISE(ABORT,'injected'); END");
            CHECK(host.fire_local(input, observation).result.code == Error::StorageUnavailable);
            CHECK(host.active_shots().empty() && inventory.snapshot()->items.at(id(100)).quantity == 1);
            db.exec("DROP TRIGGER fail_shot");
        }
        auto accepted = host.fire_local(input, observation); original = accepted.accepted;
        CHECK(accepted.result.applied() && original && host.active_shots().size() == 1);
        using namespace astra::ballistics;
        const std::array wall{Barrier{{1, 1, 0}, {{1000000, -1000, -1000}, {1001000, 1000, 1000}}}};
        auto events = host.advance_combat(observation.authority.nowQ16 + 65536, vacuum, wall);
        CHECK(events.size() == 1 && events[0].impact.shotId == 1 && host.active_shots().empty());
        CHECK(host.close().applied());
    }
    {
        DurableInventory inventory(std::make_unique<SQLiteStore>(path), initial);
        HostSession host(inventory, session_info(), {14, 1}, fixed_time);
        CHECK(inventory.snapshot()->items.at(id(100)).quantity == 0);
        auto replay = host.fire_local(input, {});
        CHECK(replay.result.applied() && replay.result.sequence == 1 && replay.accepted == original);
        CHECK(host.active_shots().empty());
        CHECK(host.advance_combat(101 * 65536, vacuum, {}).empty());
        CHECK(host.close().applied());
    }
}
