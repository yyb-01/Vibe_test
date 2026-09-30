#include "fire_scenario.hpp"

void chamber_transactions() {
    FireScenario f; auto fire = shot_request(*f.inventory.snapshot());
    CHECK(f.inventory.apply(fire, approve_fire(fire, shot_authority(), f.access)).applied());
    auto empty = f.inventory.snapshot(); CHECK(!chamber_state(*empty, id(104)).round);
    auto request = chamber_request(*empty, id(104), id(106), {88, 2}, 2, 99);
    CHECK(request.operation == Operation::Split && request.moves[0].quantity == 1);
    auto prepared = f.inventory.prepare(request, f.access);
    CHECK(prepared.changes && prepared.result.code == Error::Pending &&
          prepared.changes->outcome.applied() && f.inventory.snapshot() == empty);
    auto target = f.inventory.checkpoint_after(prepared.changes);
    auto loadedId = chamber_state(target.world, id(104)).round;
    CHECK(bool(loadedId) && target.world.items.at(loadedId).quantity == 1);
    CHECK(f.inventory.abort(prepared.changes) && !chamber_state(*f.inventory.snapshot(), id(104)).round);
    auto result = f.inventory.apply(request, f.access);
    CHECK(result.applied() && bool(result.created));
    auto loaded = f.inventory.snapshot(); loadedId = chamber_state(*loaded, id(104)).round;
    CHECK(loadedId == result.created && loaded->items.at(id(106)).quantity == 18);
    CHECK(f.inventory.apply(request, f.access).created == loadedId);
    rejects([&] { chamber_request(*loaded, id(104), id(106), {88, 3}, 3, 99); }, Error::NotAccessible);
    Inventory recovered(decode_checkpoint(encode_checkpoint(f.inventory.checkpoint())));
    CHECK(chamber_state(*recovered.snapshot(), id(104)).round == loadedId);
    fire.id.lo = fire.shot->intent.fireSeq = fire.shot->intent.inputSeq = 2; fire.actionSeq = 3;
    fire.moves = {move(*loaded, loadedId, id(50), 0), move(*loaded, id(104), id(20), 0)};
    CHECK(recovered.apply(fire, approve_fire(fire, shot_authority(), f.access)).applied());
    CHECK(!chamber_state(*recovered.snapshot(), id(104)).round);
    CHECK(recovered.snapshot()->items.at(id(104)).durability == 65525);
    auto last = *empty; last.items.at(id(106)).quantity = 1;
    Inventory single(fire_catalog(), last, 1, 1);
    request = chamber_request(*single.snapshot(), id(104), id(106), {88, 1}, 1, 99);
    CHECK(request.operation == Operation::Move);
    CHECK(single.apply(request, f.access).applied());
    CHECK(chamber_state(*single.snapshot(), id(104)).round == id(106));
}
