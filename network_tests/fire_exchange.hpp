#pragma once
#include "loopback.hpp"
#include "transport.hpp"
#include "client_transport.hpp"

inline std::vector<std::uint8_t> exchange_fire(astra::HostTransport& host, astra::ClientTransport& client,
    Loopback& socket, std::uint64_t token, const astra::FireObservation& observation) {
    astra::StreamDecoder receive;
    eventually([&] {
        auto output = client.output(token);
        if (!output.empty()) client.sent(token, socket.client.write(output.first(1)));
        auto in = socket.server->read(1);
        if (!in.empty()) socket.server->consume(host.receive(in, {}, observation));
        if (!host.output().empty()) host.sent(socket.server->write(host.output().first(1)));
        in = socket.client.read(1);
        if (!in.empty()) {
            auto consumed = client.receive(token, in);
            CHECK(receive.receive(in.first(consumed)) == consumed);
            socket.client.consume(consumed);
        }
        return receive.complete();
    });
    CHECK(client.output(token).empty()); return receive.take();
}
