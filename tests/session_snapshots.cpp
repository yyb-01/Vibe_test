#include "session_fixture.hpp"

void session_snapshots() {
    SessionScenario f; auto c = f.join(); auto state = f.access(); state.roots.resize(1);
    auto token = f.host.grant_lease(c, state);
    auto descriptor = f.host.start_snapshot(c, token, state);
    auto request = f.local_request();
    CHECK(f.host.apply_local(request, f.local_access()).code == Error::Pending);
    f.written(); CHECK(f.host.apply_local(request, f.local_access()).applied());
    SnapshotAssembly assembly(descriptor);
    assembly.receive(f.host.snapshot_page(c, descriptor.id, 0, state));
    auto world = decode_view(assembly.bytes(), catalog());
    CHECK(descriptor.sequence == 0 && world.items.at(id(100)).quantity == 20);
    CHECK(f.s.inventory->snapshot()->items.at(id(100)).quantity == 13);
    CHECK(!world.items.contains(id(104)) && !world.containers.contains(id(20)));
    auto bad = state; bad.roots[0].lineOfSight = false;
    rejects([&] { f.host.snapshot_page(c, descriptor.id, 0, bad); }, Error::NotAccessible);
    rejects([&] { f.host.snapshot_page(c, descriptor.id, 0, state); }, Error::NotAccessible);
    descriptor = f.host.start_snapshot(c, token, state);
    auto old = descriptor.id;
    descriptor = f.host.start_snapshot(c, token, state);
    rejects([&] { f.host.snapshot_page(c, old, 0, state); }, Error::NotAccessible);
    f.host.revoke_lease(c);
    rejects([&] { f.host.snapshot_page(c, descriptor.id, 0, state); }, Error::NotAccessible);
    f.host.disconnect(c); auto newConnection = f.join();
    rejects([&] { f.host.snapshot_page(newConnection, descriptor.id, 0, f.access()); }, Error::NotAccessible);
}
