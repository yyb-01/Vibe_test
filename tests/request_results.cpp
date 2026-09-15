#include "scenario.hpp"

void request_results() {
    Scenario s; auto request = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20))});
    auto before = s.inventory.checkpoint();
    CHECK(!s.inventory.result_for(request, s.access.account));
    CHECK(encode_checkpoint(before) == encode_checkpoint(s.inventory.checkpoint()));
    auto prepared = s.inventory.prepare(request, s.access);
    CHECK(prepared.changes && s.inventory.result_for(request, s.access.account)->code == Error::Pending);
    CHECK(!s.inventory.result_for(request, {77,2}));
    auto forged = request; --forged.moves[0].quantity;
    CHECK(s.inventory.result_for(forged, s.access.account)->code == Error::IdempotencyMismatch);
    CHECK(s.inventory.abort(prepared.changes));
    CHECK(!s.inventory.result_for(request, s.access.account));
    auto result = s.inventory.apply(request, s.access);
    CHECK(result.applied() && s.inventory.result_for(request, s.access.account)->sequence == result.sequence);
    Inventory restored(decode_checkpoint(encode_checkpoint(s.inventory.checkpoint())));
    CHECK(restored.result_for(request, s.access.account)->sequence == result.sequence);
    CHECK(restored.result_for(forged, s.access.account)->code == Error::IdempotencyMismatch);
    auto denied = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(101), id(20), 50)});
    CHECK(s.inventory.apply(denied, s.access).code == Error::InvalidPlacement);
    CHECK(s.inventory.result_for(denied, s.access.account)->code == Error::InvalidPlacement);
    CHECK(s.inventory.result_for(request, {})->code == Error::NotAccessible);
}
