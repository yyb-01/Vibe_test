#include "session_fixture.hpp"
#include "client_state.hpp"
#include "shutdown.hpp"

void client_shutdown() {
    SessionScenario f; auto c = f.join();
    auto resume = f.host.resume_state(c); ClientState client(resume, catalog());
    auto packet = f.packet(); auto request = decode_packet(packet, resume.epoch).request;
    client.track(request); auto original = client.retry_payload(request.id);
    client.set_roots({id(10), id(20), id(30)});
    auto d = f.host.start_snapshot(c, f.remoteLease, f.access());
    client.begin_snapshot(d);
    CHECK(client.receive_page(f.host.snapshot_page(c, d.id, 0, f.access())));
    auto view = client.view();
    PacketHeader h; h.worldEpoch = resume.epoch; h.messageType = MessageType::SessionClosing;
    auto bad = encode_shutdown(h, 0); bad.pop_back();
    rejects([&] { client.receive_shutdown(bad); }, Error::InvalidRequest);
    CHECK(client.connected() && client.view() == view);
    { std::lock_guard lock(f.s.probe->mutex); f.s.probe->hold = true; }
    CHECK(f.host.receive(c, packet, f.access()).code == Error::Pending);
    CHECK(f.host.prepare_close().code == Error::Pending && client.connected());
    f.s.probe->release(); Result ready;
    eventually([&] { ready = f.host.prepare_close(); return ready.code != Error::Pending; });
    CHECK(ready.applied() && ready.sequence == 1 && f.s.probe->closes == 0);
    auto notice = encode_shutdown(h, ready.sequence); client.receive_shutdown(notice);
    CHECK(!client.connected() && !client.view() && !client.needs_refresh());
    CHECK(client.status(request.id).status == TransactionStatus::Resolving);
    CHECK(client.retry_payload(request.id) == original);
    client.receive_shutdown(notice); // Delivery/close retries remain harmless.
    rejects([&] { client.track(request); }, Error::NotAccessible);
    rejects([&] { client.reconnect(resume); }, Error::RevisionConflict);
    auto stale = encode_shutdown(h, 0);
    rejects([&] { client.receive_shutdown(stale); }, Error::RevisionConflict);
    f.s.probe->closeFails = true; Result closed;
    eventually([&] { closed = f.host.close(); return closed.code != Error::Pending; });
    CHECK(closed.code == Error::StorageUnavailable && !client.connected());
    f.s.probe->closeFails = false;
    eventually([&] { closed = f.host.close(); return closed.code != Error::Pending; });
    CHECK(closed.applied() && f.s.probe->saves == 1);
}
