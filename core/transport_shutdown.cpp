#include "transport.hpp"
#include "shutdown.hpp"

namespace astra {
Result HostTransport::shutdown() {
    host_.info(); require(connection_ && !closing_, Error::InvalidState);
    require(output().empty(), Error::Busy);
    require(!snapshot_ || snapshot_page_ == snapshot_pages(*snapshot_), Error::Busy);
    auto ready = host_.prepare_close();
    if (ready.applied()) {
        PacketHeader h; h.worldEpoch = host_.info().epoch;
        h.messageType = MessageType::SessionClosing;
        output_ = encode_stream(encode_shutdown(h, ready.sequence));
        closing_ = true;
    }
    return ready;
}
}
