#include "sqlite_fault_store.hpp"
#include "../tests/magazine_fixture.hpp"

void sqlite_magazine(const std::filesystem::path& path) {
    Request feed; Id round;
    {
        auto driver = std::make_unique<LostReply>(path); auto* fault = driver.get();
        DurableInventory world(std::move(driver), magazine_checkpoint());
        auto before = world.snapshot();
        feed = feed_request(*before, id(104), id(108), {88, 1}, 1, 99);
        {
            sq::Connection db(path);
            db.exec("CREATE TRIGGER fail_feed AFTER UPDATE ON world BEGIN SELECT RAISE(ABORT,'injected'); END");
            CHECK(world.apply(feed, access(world)).code == Error::StorageUnavailable);
            CHECK(world.snapshot() == before && fault->real.inspect().checkpoint.requests.empty());
            db.exec("DROP TRIGGER fail_feed");
        }
        CHECK(world.apply(feed, access(world)).code == Error::Pending && world.snapshot() == before);
        auto saved = fault->real.inspect(); round = chamber_state(saved.checkpoint.world, id(104)).round;
        CHECK(bool(round) && magazine_state(saved.checkpoint.world, id(108)).rounds == 4);
        auto committed = world.resolve(); CHECK(committed.applied() && committed.created == round);
        CHECK(world.apply(feed, access(world)).created == round);
        auto loaded = world.snapshot(); CHECK(loaded->items.at(round).wetness == 10);
        auto fire = shot_request(fire_seed()); fire.actionSeq = 2;
        fire.moves = {move(*loaded, round, id(50), 0), move(*loaded, id(104), id(20), 0)};
        CHECK(world.apply(fire, approve_fire(fire, shot_authority(), access(world))).code == Error::Pending);
        CHECK(world.snapshot() == loaded && world.resolve().applied());
        CHECK(!chamber_state(*world.snapshot(), id(104)).round && world.close().applied());
    }
    {
        DurableInventory world(std::make_unique<SQLiteStore>(path), magazine_checkpoint());
        CHECK(world.apply(feed, access(world)).created == round);
        auto recovered = world.snapshot();
        CHECK(!chamber_state(*recovered, id(104)).round);
        auto mag = magazine_state(*recovered, id(108)); CHECK(mag.rounds == 4 && mag.nextRound == id(110));
        auto next = feed_request(*recovered, id(104), id(108), {88, 3}, 3, 99);
        CHECK(next.operation == Operation::Move && world.apply(next, access(world)).applied());
        CHECK(chamber_state(*world.snapshot(), id(104)).round == id(110));
        CHECK(magazine_state(*world.snapshot(), id(108)).nextRound == id(109));
        CHECK(world.close().applied());
    }
}
