#include "magazine_fixture.hpp"

void magazine_feed() {
    auto inv = std::make_unique<Inventory>(magazine_checkpoint());
    Access access{{77, 1}, 1, 99, {id(10), id(20)}};
    const std::array<unsigned, 5> defs{1, 1, 5, 1, 1}, wet{10, 10, 0, 20, 20};
    for (unsigned i = 0; i < 5; ++i) {
        auto before = inv->snapshot(); auto state = magazine_state(*before, id(108));
        CHECK(state.rounds == 5 - i && bool(state.nextRound));
        auto seq = inv->next_action_sequence(access.account);
        auto request = feed_request(*before, id(104), id(108), {88, seq}, seq, 99);
        if (!i) {
            auto prepared = inv->prepare(request, access);
            CHECK(prepared.result.code == Error::Pending && prepared.changes->outcome.applied());
            CHECK(inv->snapshot() == before && inv->abort(prepared.changes));
        }
        auto result = inv->apply(request, access); CHECK(result.applied());
        auto loaded = inv->snapshot(); auto round = chamber_state(*loaded, id(104)).round;
        CHECK(bool(round) && loaded->items.at(round).quantity == 1);
        CHECK(loaded->items.at(round).defId == defs[i] && loaded->items.at(round).wetness == wet[i]);
        CHECK(magazine_state(*loaded, id(108)).rounds == 4 - i);
        CHECK(inv->apply(request, access).sequence == result.sequence && inv->snapshot() == loaded);
        if (i == 2) inv = std::make_unique<Inventory>(decode_checkpoint(encode_checkpoint(inv->checkpoint())));
        auto fire = shot_request(fire_seed());
        fire.id.lo = fire.shot->intent.inputSeq = fire.shot->intent.fireSeq = i + 1;
        fire.actionSeq = inv->next_action_sequence(access.account); fire.shot->ammoDef = defs[i];
        fire.moves = {move(*loaded, round, id(50), 0), move(*loaded, id(104), id(20), 0)};
        auto accepted = inv->apply(fire, approve_fire(fire, shot_authority(), access)); CHECK(accepted.applied());
        CHECK(inv->apply(fire, access).sequence == accepted.sequence);
        CHECK(!chamber_state(*inv->snapshot(), id(104)).round);
    }
    auto after = inv->snapshot(); CHECK(magazine_state(*after, id(108)).rounds == 0);
    CHECK(after->items.at(id(104)).durability == 65510 && after->items.at(id(106)).quantity == 19);
    rejects([&] { feed_request(*after, id(104), id(108), {88, 11}, 11, 99); }, Error::NotAccessible);
}
