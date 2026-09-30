#include "session.hpp"

void tcp_failures() {
    for (bool truncated : {false, true}) {
        TcpSession s; s.ready();
        const std::uint8_t prefix[]{255,255,255,255};
        CHECK(s.command->client.write(std::span(prefix).first(truncated ? 1 : 4)) == (truncated ? 1u : 4u));
        CHECK(shutdown(s.command->client.native(), SD_SEND) == 0);
        rejects([&] { eventually([&] { s.tick(); return !s.host->connection(); }); }, Error::InvalidRequest);
        CHECK(!s.client.poll(s.token) && s.f.host.players() == 1);
    }
    {
        TcpSession s; s.ready(); s.client.request_snapshot(s.token);
        CHECK(shutdown(s.snapshot->server->native(), SD_SEND) == 0);
        rejects([&] { eventually([&] { s.tick(7, false); return !s.client.poll(s.token); }); }, Error::InvalidRequest);
        CHECK(s.f.host.players() == 1);
    }
    {
        static TransportDeadlines::Clock::time_point time;
        time = {}; TcpSession s(+[] { return time; });
        time += std::chrono::seconds(1); s.tick();
        CHECK(!s.client.poll(s.token) && !s.host->connection() && s.f.host.players() == 1);
        CHECK(s.command->client.native() == INVALID_SOCKET);
    }
}
