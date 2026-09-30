#include "session.hpp"

void tcp_transactions() {
    TcpSession s; s.ready();
    s.client.request_snapshot(s.token);
    eventually([&] { s.tick(); return bool(s.client.state().view()); });
    auto request = s.f.s.request(); request.interactionLease = s.client.snapshot_lease(s.token);
    s.client.submit(s.token, request);
    eventually([&] { s.tick(); return s.f.s.probe->saves == 1 && s.host->output().empty(); });
    s.f.written(); s.client.retry(s.token, request.id);
    eventually([&] { s.tick(); return s.client.state().status(request.id).status == TransactionStatus::Committed; });
    s.client.request_snapshot(s.token);
    eventually([&] { s.tick(); return bool(s.client.state().view()); });
    CHECK(s.client.state().view()->items.at(id(100)).quantity == 13);
    CHECK(s.host->shutdown().applied());
    eventually([&] { s.tick(); return !s.client.poll(s.token); });
    CHECK(s.f.host.players() == 1 && s.f.s.probe->closes == 0);
    CHECK(s.client.state().status(request.id).status == TransactionStatus::Committed);
    eventually([&] { return s.f.host.close().applied(); });
}
void tcp_reconnect() {
    TcpSession s; s.ready();
    auto request = s.f.s.request();
    request.interactionLease = s.f.host.grant_lease(s.host->connection(), s.f.access());
    s.client.submit(s.token, request);
    eventually([&] { s.tick(); return s.f.s.probe->saves == 1 && s.host->output().empty(); });
    s.f.written(); s.client.retry(s.token, request.id);
    eventually([&] { s.tick(1); return s.f.s.inventory->snapshot()->items.at(id(100)).quantity == 13; });
    CHECK(s.client.state().status(request.id).status != TransactionStatus::Committed);
    auto original = s.client.state().retry_payload(request.id); auto old = s.token;
    s.drop(); s.connect(); s.ready(); s.client.disconnect(old);
    s.client.retry(s.token, request.id);
    eventually([&] { s.tick(); return s.client.state().status(request.id).status == TransactionStatus::Committed; });
    CHECK(s.token != old && s.f.s.probe->saves == 1);
    CHECK(s.client.state().retry_payload(request.id) == original);
}
