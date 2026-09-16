#include "scenario.hpp"
#include "shutdown.hpp"

void shutdown_codec() {
    PacketHeader h; h.worldEpoch = 2; h.messageType = MessageType::SessionClosing;
    auto bytes = encode_shutdown(h, 5);
    CHECK(bytes.size() == 40 && bytes[2] == 4 && bytes[28] == 8 && bytes[32] == 5);
    CHECK(decode_shutdown(bytes, 2) == 5);
    CHECK(decode_shutdown(encode_shutdown(h, 0), 2) == 0);
    CHECK(decode_shutdown(encode_shutdown(h, revision_limit), 2) == revision_limit);
    for (std::size_t n = 0; n < bytes.size(); ++n)
        rejects([&] { decode_shutdown({bytes.begin(), bytes.begin() + n}, 2); }, Error::InvalidRequest);
    auto bad = bytes; bad.push_back(0);
    rejects([&] { decode_shutdown(bad, 2); }, Error::InvalidRequest);
    bad[28] = 9; // Consistent envelope, wrong closing payload length.
    rejects([&] { decode_shutdown(bad, 2); }, Error::InvalidRequest);
    bad = bytes; bad[39] = 128;
    rejects([&] { decode_shutdown(bad, 2); }, Error::InvalidRequest);
    rejects([&] { encode_shutdown(h, revision_limit + 1); }, Error::InvalidRequest);
    rejects([&] { decode_shutdown(bytes, 3); }, Error::EpochMismatch);
    rejects([&] { decode_shutdown(bytes, 2, 39); }, Error::InvalidRequest);
    rejects([&] { encode_shutdown(h, 5, 39); }, Error::LimitExceeded);
    bad = bytes; bad[2] = 3;
    rejects([&] { decode_shutdown(bad, 2); }, Error::Incompatible);
    bad = bytes; bad[0] = 2;
    rejects([&] { decode_shutdown(bad, 2); }, Error::Incompatible);
    bad = bytes; bad[30] = 1;
    rejects([&] { decode_shutdown(bad, 2); }, Error::InvalidRequest);
}
