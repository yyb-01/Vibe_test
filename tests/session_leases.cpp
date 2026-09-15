#include "session_fixture.hpp"
#include <limits>

void session_leases() {
    SessionScenario f; auto c = f.join(); auto state = f.access(); auto& h = f.host;
    auto scoped = state; scoped.roots.resize(1);
    auto lease = h.grant_lease(c, scoped);
    auto snapshot = h.view(c, lease, scoped);
    CHECK(snapshot.roots.size() == 1 && snapshot.roots.contains(id(10)));
    CHECK(!snapshot.roots.at(id(10))->items.contains(id(104)));
    rejects([&] { h.view(HostSession::host_connection, lease, f.local_access()); }, Error::NotAccessible);
    rejects([&] { h.view(c, lease, state); }, Error::NotAccessible);
    for (double distance : {-1., 2.500001, std::numeric_limits<double>::infinity(),
                            std::numeric_limits<double>::quiet_NaN()}) {
        auto bad = scoped; bad.roots[0].distanceM = distance;
        rejects([&] { h.grant_lease(c, bad); }, Error::NotAccessible);
        rejects([&] { h.view(c, lease, bad); }, Error::NotAccessible);
    }
    for (int n = 0; n < 8; ++n) {
        auto bad = scoped;
        if (n == 0) bad.alive = false;
        if (n == 1) bad.canInteract = false;
        if (n == 2) bad.roots[0].lineOfSight = false;
        if (n == 3) bad.roots[0].permitted = false;
        if (n == 4) bad.pawn = {14,1};
        if (n == 5) bad.roots.clear();
        if (n == 6) bad.roots.push_back(bad.roots[0]);
        if (n == 7) bad.roots.resize(17, bad.roots[0]);
        rejects([&] { h.grant_lease(c, bad); }, Error::NotAccessible);
    }
    auto missing = scoped; missing.roots[0].root = id(999);
    rejects([&] { h.grant_lease(c, missing); }, Error::NotAccessible);
    missing.roots[0].root = id(40); // Child container is not an independent root.
    rejects([&] { h.grant_lease(c, missing); }, Error::NotAccessible);
    auto next = h.grant_lease(c, scoped); CHECK(next != lease);
    rejects([&] { h.view(c, lease, scoped); }, Error::NotAccessible);
    h.revoke_lease(c);
    rejects([&] { h.view(c, next, scoped); }, Error::NotAccessible);
    CHECK(f.s.probe->saves == 0 && f.s.inventory->next_action_sequence(f.remote.account) == 1);
}

namespace {
TransactionBudget::Clock::time_point test_time;
auto clock_now() { return test_time; }
}
void session_lease_expiry() {
    using namespace std::chrono;
    test_time = {}; SessionScenario f(clock_now); auto c = f.join(); auto state = f.access();
    test_time += interaction_lease_lifetime - milliseconds(1);
    CHECK(f.host.view(c, f.remoteLease, state).roots.size() == 3);
    test_time += milliseconds(1);
    rejects([&] { f.host.view(c, f.remoteLease, state); }, Error::NotAccessible);
    CHECK(f.host.receive(c, f.packet(), state).code == Error::NotAccessible);
    test_time += seconds(1);
    auto lease = f.host.grant_lease(c, state);
    test_time -= milliseconds(1);
    rejects([&] { f.host.view(c, lease, state); }, Error::NotAccessible);
}
