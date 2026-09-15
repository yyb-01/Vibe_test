#include "session_fixture.hpp"

void session_lease_replay() {
    SessionScenario f; auto c = f.join(); auto& h = f.host; auto bytes = f.packet();
    auto blocked = f.access(); blocked.roots[1].lineOfSight = false;
    CHECK(h.receive(c, bytes, blocked).code == Error::NotAccessible);
    CHECK(f.s.probe->saves == 0);
    { std::lock_guard lock(f.s.probe->mutex); f.s.probe->hold = true; }
    CHECK(h.receive(c, bytes, f.access()).code == Error::Pending);
    h.revoke_lease(c);
    CHECK(h.receive(c, bytes, {}).code == Error::Pending);
    auto request = decode_packet(bytes, h.info().epoch).request;
    CHECK(!f.s.inventory->result_for(request, f.s.access().account));
    auto forged = request; --forged.moves[0].quantity;
    PacketHeader header; header.worldEpoch = h.info().epoch;
    CHECK(h.receive(c, encode_packet(header, forged), {}).code == Error::IdempotencyMismatch);
    f.s.probe->release(); f.written();
    auto result = h.receive(c, bytes, {});
    CHECK(result.applied() && result.created && f.s.probe->saves == 1);
    CHECK(!f.s.inventory->result_for(request, f.s.access().account));
    h.disconnect(c); c = f.join();
    CHECK(h.receive(c, bytes, {}).created == result.created);
    auto fresh = f.s.request(); ++fresh.id.lo; ++fresh.actionSeq;
    fresh.interactionLease = request.interactionLease;
    CHECK(h.receive(c, encode_packet(header, fresh), f.access()).code == Error::NotAccessible);
    CHECK(f.s.inventory->next_action_sequence(f.remote.account) == 2);
    CHECK(f.s.probe->saves == 1);
}
