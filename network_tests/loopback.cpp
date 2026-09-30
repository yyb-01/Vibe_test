#include "loopback.hpp"

namespace {
void ready(SOCKET socket, bool writing) {
    fd_set active, errors; FD_ZERO(&active); FD_ZERO(&errors);
    FD_SET(socket, &active); FD_SET(socket, &errors);
    timeval timeout{5, 0};
    CHECK(select(0, writing ? nullptr : &active, writing ? &active : nullptr, &errors, &timeout) > 0);
    CHECK(!FD_ISSET(socket, &errors));
}
}
Loopback::Loopback() {
    astra::tcp::Stream listener;
    BOOL exclusive = TRUE;
    CHECK(setsockopt(listener.native(), SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
        reinterpret_cast<const char*>(&exclusive), sizeof(exclusive)) == 0);
    sockaddr_in address{}; address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK); // OS chooses an unused port.
    CHECK(bind(listener.native(), reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0);
    int size = sizeof(address);
    CHECK(getsockname(listener.native(), reinterpret_cast<sockaddr*>(&address), &size) == 0);
    CHECK(listen(listener.native(), 1) == 0);
    int connected = connect(client.native(), reinterpret_cast<sockaddr*>(&address), sizeof(address));
    CHECK(connected == 0 || WSAGetLastError() == WSAEWOULDBLOCK);
    ready(client.native(), true);
    int error = 0; size = sizeof(error);
    CHECK(getsockopt(client.native(), SOL_SOCKET, SO_ERROR, reinterpret_cast<char*>(&error), &size) == 0 && error == 0);
    ready(listener.native(), false);
    sockaddr_in peer{}; size = sizeof(peer);
    server.emplace(accept(listener.native(), reinterpret_cast<sockaddr*>(&peer), &size));
    sockaddr_in local{}; size = sizeof(local);
    CHECK(getsockname(client.native(), reinterpret_cast<sockaddr*>(&local), &size) == 0);
    CHECK(peer.sin_addr.s_addr == htonl(INADDR_LOOPBACK) && peer.sin_port == local.sin_port);
}
