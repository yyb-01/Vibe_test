#include "session_fixture.hpp"

void session_commands() {
    SessionScenario f; auto& h = f.host; auto c = f.join();
    auto bytes = f.packet(); auto access = f.access(); auto before = f.s.inventory->snapshot();
    CHECK(h.receive(0, bytes, access).code == Error::NotAccessible);
    CHECK(h.receive(c, bytes, f.local_access()).code == Error::NotAccessible);
    auto bad = bytes; ++bad[4];
    CHECK(h.receive(c, bad, access).code == Error::EpochMismatch);
    CHECK(f.s.inventory->snapshot() == before && f.s.probe->saves == 0);
    CHECK(h.receive(c, bytes, access).code == Error::Pending);
    f.written();
    auto result = h.receive(c, bytes, access);
    CHECK(result.applied() && result.sequence == 1);
    h.disconnect(c); auto reconnect = f.join();
    CHECK(h.receive(c, bytes, access).code == Error::NotAccessible);
    CHECK(h.receive(reconnect, bytes, access).created == result.created);
    CHECK(f.s.probe->saves == 1);
    auto denied = f.local_request(); denied.moves[0].itemRev = 0;
    CHECK(h.apply_local(denied, f.local_access()).code == Error::Pending);
    f.written();
    CHECK(h.apply_local(denied, f.local_access()).code == Error::RevisionConflict);
    CHECK(f.s.inventory->snapshot()->items.at(id(100)).quantity == 13);
}

void session_rate_limits() {
    SessionScenario f; auto& h = f.host; auto c = f.join();
    for (int n = 0; n < 20; ++n)
        CHECK(h.receive(c, {}, f.access()).code == Error::InvalidRequest);
    CHECK(h.receive(c, f.packet(), f.access()).code == Error::Busy);
    h.disconnect(c); c = f.join();
    CHECK(h.receive(c, f.packet(), f.access()).code == Error::Busy);
    CHECK(f.s.probe->saves == 0);
    auto malformed = f.local_request(); malformed.moves.clear();
    for (int n = 0; n < 20; ++n)
        CHECK(h.apply_local(malformed, f.local_access()).code == Error::InvalidRequest);
    CHECK(h.apply_local(f.local_request(), f.local_access()).code == Error::Busy);
    h.disconnect(c);
    for (std::uint64_t n = 3; n <= 64; ++n) {
        auto joined = h.admit_authenticated({{77,n},{14,n}}, h.info());
        h.disconnect(joined);
    }
    rejects([&] { h.admit_authenticated({{77,65},{14,65}}, h.info()); }, Error::LimitExceeded);
    CHECK(f.join() != c);
}
