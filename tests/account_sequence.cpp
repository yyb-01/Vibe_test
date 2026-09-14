#include "scenario.hpp"

void account_sequence() {
    Scenario s;
    auto account = s.access.account;
    CHECK(s.inventory.next_action_sequence(account) == 1);
    rejects([&] { (void)s.inventory.next_action_sequence({}); }, Error::NotAccessible);
    auto r = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20))});
    auto prepared = s.inventory.prepare(r, s.access);
    CHECK(prepared.changes && s.inventory.next_action_sequence(account) == 1);
    CHECK(s.inventory.abort(prepared.changes));
    CHECK(s.inventory.next_action_sequence(account) == 1);
    CHECK(s.inventory.apply(r, s.access).applied());
    CHECK(s.inventory.next_action_sequence(account) == 2);
    CHECK(s.inventory.apply(r, s.access).applied());
    CHECK(s.inventory.next_action_sequence(account) == 2);
    auto denied = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(10), 32)});
    CHECK(s.inventory.apply(denied, s.access).code == Error::InvalidPlacement);
    Inventory restored(s.inventory.checkpoint());
    CHECK(restored.next_action_sequence(account) == 3);
    CHECK(restored.next_action_sequence({77, 2}) == 1);
}
