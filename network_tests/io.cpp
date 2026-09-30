#include "loopback.hpp"
#include <algorithm>
#include <system_error>

void tcp_io() {
    Loopback link;
    CHECK(link.server->read().empty() && !link.server->eof()); // WSAEWOULDBLOCK, not EOF.
    const std::uint8_t data[]{1,2,3,4,5};
    std::size_t sent = 0, received = 0;
    eventually([&] {
        sent += link.client.write(std::span(data).subspan(sent));
        auto bytes = link.server->read(3); // Force multiple reads; TCP may split them further.
        if (!bytes.empty()) {
            CHECK(bytes.front() == data[received]);
            rejects([&] { link.server->consume(bytes.size() + 1); }, astra::Error::InvalidRequest);
            auto remaining = bytes.size() - 1;
            link.server->consume(1); ++received;
            if (remaining) {
                auto suffix = link.server->read(3);
                CHECK(suffix.size() == remaining && suffix.front() == data[received]);
            }
        }
        return received == std::size(data);
    });
    CHECK(shutdown(link.client.native(), SD_SEND) == 0);
    eventually([&] { CHECK(link.server->read().empty()); return link.server->eof(); });
    rejects([&] { link.server->read(0); }, astra::Error::InvalidRequest);

    Loopback reset; linger abortive{1,0};
    CHECK(setsockopt(reset.client.native(), SOL_SOCKET, SO_LINGER,
        reinterpret_cast<const char*>(&abortive), sizeof(abortive)) == 0);
    reset.client.close(); bool failed = false;
    eventually([&] {
        try { reset.server->read(); } catch (const std::system_error&) { failed = true; }
        return failed;
    });
    CHECK(reset.server->native() == INVALID_SOCKET);
}
void tcp_backpressure() {
    Loopback link; int small = 1024;
    CHECK(setsockopt(link.client.native(), SOL_SOCKET, SO_SNDBUF,
        reinterpret_cast<const char*>(&small), sizeof(small)) == 0);
    std::array<std::uint8_t, 4096> data; data.fill(17);
    std::size_t sent = 0; bool blocked = false;
    for (unsigned i = 0; i < 8192; ++i) {
        auto n = link.client.write(data); sent += n;
        if (!n) { blocked = true; break; }
    }
    CHECK(blocked && sent > 0);
    std::size_t received = 0;
    eventually([&] {
        auto bytes = link.server->read();
        CHECK(std::all_of(bytes.begin(), bytes.end(), [](auto x) { return x == 17; }));
        received += bytes.size(); link.server->consume(bytes.size());
        return received == sent;
    });
    eventually([&] { return link.client.write(data) > 0; }); // Allow the TCP window update to arrive.
}
