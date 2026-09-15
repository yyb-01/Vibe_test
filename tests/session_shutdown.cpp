#include "session_fixture.hpp"

void session_shutdown() {
    SessionScenario f; auto& h = f.host; auto c = f.join();
    { std::lock_guard lock(f.s.probe->mutex); f.s.probe->hold = true; }
    auto before = f.s.inventory->snapshot(); auto bytes = f.packet();
    CHECK(h.receive(c, bytes, f.access()).code == Error::Pending);
    auto other = f.local_request(); ++other.id.lo;
    CHECK(h.apply_local(other, f.local_access()).code == Error::Busy);
    CHECK(h.prepare_close().code == Error::Pending && h.players() == 2);
    CHECK(f.s.probe->closes == 0);
    CHECK(h.receive(c, bytes, f.access()).code == Error::Busy);
    CHECK(h.apply_local(other, f.local_access()).code == Error::Busy);
    rejects([&] { h.admit_authenticated({{77,3},{14,3}}, h.info()); }, Error::Busy);
    CHECK(f.s.inventory->snapshot() == before);
    f.s.probe->closeFails = true; f.s.probe->release();
    Result result;
    eventually([&] { result = h.prepare_close(); return result.code != Error::Pending; });
    CHECK(result.applied() && result.sequence == 1 && h.players() == 2);
    CHECK(f.s.probe->closes == 0 && h.prepare_close().applied());
    CHECK(f.s.inventory->apply(other, f.s.access()).code == Error::Busy);
    eventually([&] { result = h.close(); return result.code != Error::Pending; });
    CHECK(result.code == Error::StorageUnavailable && h.players() == 2);
    CHECK(f.s.inventory->snapshot()->items.at(id(100)).quantity == 13);
    f.s.probe->closeFails = false;
    eventually([&] { result = h.close(); return result.code != Error::Pending; });
    CHECK(result.applied() && h.players() == 0 && f.s.probe->saves == 1);
    CHECK(h.close().applied());
    rejects([&] { f.join(); }, Error::Busy);
}
