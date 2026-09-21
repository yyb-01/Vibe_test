#include "transport.hpp"
#include "client_transport.hpp"

namespace astra {
bool HostTransport::poll() {
    host_.info();
    if (!connection_) return false;
    try { if (deadlines_.expired()) disconnect(); }
    catch (...) { disconnect(); throw; }
    return connection_ != 0;
}
bool ClientTransport::poll(std::uint64_t token) {
    owner();
    if (!active_ || token != generation_) return false;
    try { if (deadlines_.expired()) disconnect(token); }
    catch (...) { disconnect(token); throw; }
    return active_;
}
}
