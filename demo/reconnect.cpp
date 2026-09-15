#include "session.hpp"

void Session::disconnect() {
    require(bool(client) && !closing, Error::InvalidRequest);
    client->disconnect();
}
void Session::reconnect() {
    require(bool(client) && !closing, Error::InvalidRequest);
    if (!client->connected()) client->reconnect();
    if (pending) { resolve(); require(!pending, Error::Busy); }
    // Refresh authority only after resolving the original request.
    client->snapshot();
}
