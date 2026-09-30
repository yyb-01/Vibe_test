#include "session.hpp"
#include <algorithm>

void TcpSession::connect() {
    command = std::make_unique<Loopback>(); snapshot = std::make_unique<Loopback>();
    host = std::make_unique<HostTransport>(f.host, f.remote, f.host.info(), std::chrono::seconds(1), now);
    token = client.open_authenticated(baseline.epoch);
}
void TcpSession::drop() {
    host->disconnect(); client.disconnect(token); command->close(); snapshot->close();
}
void TcpSession::host_tick(std::size_t chunk, bool sendSnapshot) {
    if (!host->poll()) { command->server->close(); return; }
    auto bytes = command->server->read(chunk);
    if (command->server->eof()) { host->finish(); return; }
    if (!bytes.empty()) command->server->consume(host->receive(bytes, f.access()));
    auto out = host->output();
    if (!out.empty()) host->sent(command->server->write(out.first(std::min(chunk, out.size()))));
    if (!host->poll() || !sendSnapshot) return;
    try { out = host->snapshot_output(f.access()); }
    catch (const Violation& e) { if (e.code == Error::Busy) return; throw; }
    if (!out.empty()) host->snapshot_sent(snapshot->server->write(out.first(std::min(chunk, out.size()))));
}
void TcpSession::client_tick(std::size_t chunk) {
    if (!client.poll(token)) return;
    auto out = client.output(token);
    if (!out.empty()) client.sent(token, command->client.write(out.first(std::min(chunk, out.size()))));
    auto bytes = command->client.read(chunk);
    if (command->client.eof()) { client.finish(token); return; }
    if (!bytes.empty()) command->client.consume(client.receive(token, bytes));
    if (!client.poll(token)) return;
    bytes = snapshot->client.read(chunk);
    if (snapshot->client.eof()) { client.finish_snapshot(token); return; }
    if (!bytes.empty()) snapshot->client.consume(client.receive_snapshot(token, bytes));
}
void TcpSession::tick(std::size_t chunk, bool sendSnapshot) {
    try {
        host_tick(chunk, sendSnapshot); client_tick(chunk);
        // Drain the closing notice on the command stream before closing the other channel.
        if (!client.poll(token)) drop();
    } catch (...) { drop(); throw; }
}
