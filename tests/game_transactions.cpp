#include "scenario.hpp"
#include "snapshot.hpp"
#include "packet.hpp"
void game_transactions() {
    Scenario s; auto before = s.inventory.snapshot();
    Request r{{88, 900}, 1, Operation::System, {}, 0, 99};
    r.systemRoots = {id(10), id(20)}; r.command = {3, 9}; r.newIds = 1;
    int runs = 0;
    r.mutation = [&](World& w, Id created, std::uint64_t event) {
        ++runs;
        auto& original = w.items.at(id(100)); --original.quantity; ++original.revision;
        auto output = original; output.id = created; output.quantity = 1;
        output.revision = 1; output.birthEvent = event;
        CHECK(w.items.emplace(created, output).second);
        w.placements.emplace(created, Placement{created, id(20), 0, 4});
        w.containers.at(id(20)).gameplay = {1, 2, 3};
    };
    auto access = s.access; access.approvedSystem = encode(r);
    auto pending = s.inventory.prepare(r, access);
    CHECK(pending.changes && pending.result.code == Error::Pending && runs == 1);
    CHECK(s.inventory.snapshot() == before);
    auto delta = decode_delta(encode_delta(s.inventory.checkpoint_delta(pending.changes)));
    auto next = s.inventory.checkpoint(); apply_checkpoint_delta(next, delta);
    CHECK(next.world.containers.at(id(20)).gameplay.size() == 3);
    auto done = s.inventory.commit(pending.changes);
    CHECK(done.applied() && s.inventory.apply(r, access).sequence == done.sequence && runs == 1);
    auto checkpoint = decode_checkpoint(encode_checkpoint(s.inventory.checkpoint()));
    CHECK(checkpoint.world == *s.inventory.snapshot());
    Inventory restored{checkpoint}; CHECK(restored.apply(decode(encode(r)), access).applied());
    auto publicView = decode_view(encode_view(s.inventory.snapshot_roots({id(20)})), catalog());
    CHECK(publicView.containers.at(id(20)).gameplay.empty());
    auto altered = r; altered.command.push_back(4);
    CHECK(restored.apply(altered, access).code == Error::IdempotencyMismatch);
    rejects([&] { encode_packet({}, r); }, Error::InvalidRequest);
    Scenario blocked; CHECK(blocked.inventory.apply(r, blocked.access).code == Error::NotAccessible);
    CHECK(blocked.inventory.snapshot()->items.at(id(100)).quantity == 20);
}
