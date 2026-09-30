#pragma once
#include "../net/tcp_stream.hpp"
#include "../tests/check.hpp"
#include <optional>

// Test-only listener. No public address or client-supplied account is accepted.
struct Loopback {
    astra::tcp::Stream client;
    std::optional<astra::tcp::Stream> server;
    Loopback();
    void close() { client.close(); server->close(); }
};
