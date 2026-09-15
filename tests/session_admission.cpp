#include "session_fixture.hpp"

void session_admission() {
    SessionScenario f; auto& h = f.host;
    CHECK(h.players() == 1 && h.info().epoch == f.s.inventory->epoch());
    auto info = h.info();
    auto bad = info; ++bad.epoch;
    rejects([&] { h.admit_authenticated(f.remote, bad); }, Error::EpochMismatch);
    for (int field = 0; field < 6; ++field) {
        bad = info;
        if (field == 0) ++bad.protocol;
        if (field == 1) ++bad.session.lo;
        if (field == 2) ++bad.world.lo;
        if (field == 3) ++bad.host.lo;
        if (field == 4) ++bad.catalogHash[0];
        if (field == 5) bad.identity = IdentityKind::LocalLan;
        rejects([&] { h.admit_authenticated(f.remote, bad); }, Error::Incompatible);
    }
    auto lan = f.remote; lan.identity = IdentityKind::LocalLan;
    rejects([&] { h.admit_authenticated(lan, info); }, Error::NotAccessible);
    auto peer = f.remote; peer.account = {};
    rejects([&] { h.admit_authenticated(peer, info); }, Error::NotAccessible);
    auto connection = f.join();
    rejects([&] { f.join(); }, Error::NotAccessible);
    peer = f.remote; peer.account.lo = 3;
    rejects([&] { h.admit_authenticated(peer, info); }, Error::NotAccessible);
    for (std::uint64_t n = 3; n <= 20; ++n)
        h.admit_authenticated({{77,n},{14,n}}, info);
    CHECK(h.players() == 20);
    rejects([&] { h.admit_authenticated({{77,21},{14,21}}, info); }, Error::LimitExceeded);
    h.disconnect(connection);
    CHECK(h.players() == 19 && f.join() != connection);
    rejects([&] { h.disconnect(HostSession::host_connection); }, Error::NotAccessible);
    std::thread wrong([&] { rejects([&] { h.players(); }, Error::InvalidState); });
    wrong.join();
}

void transaction_budget() {
    using namespace std::chrono;
    TransactionBudget b(fixed_time()); auto t = fixed_time();
    for (int n = 0; n < 20; ++n) CHECK(b.take(t));
    CHECK(!b.take(t)); CHECK(!b.take(t + milliseconds(99)));
    CHECK(b.take(t + milliseconds(100))); CHECK(!b.take(t + milliseconds(100)));
    rejects([&] { b.take(t); }, Error::InvalidState);
    CHECK(b.take(t + milliseconds(200)));
    t += hours(24);
    for (int n = 0; n < 20; ++n) CHECK(b.take(t));
    CHECK(!b.take(t));
}
