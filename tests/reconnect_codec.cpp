#include "scenario.hpp"
#include "reconnect.hpp"

void reconnect_codec() {
    ResumeState state{{id(90), id(77), {}}, 2, 5, 3};
    state.identity.catalogHash.fill(42);
    PacketHeader h; h.worldEpoch = 2; h.messageType = MessageType::SessionResume;
    auto bytes = encode_resume(h, state);
    auto decoded = decode_resume(bytes, 2);
    CHECK(bytes.size() == 112 && bytes[2] == 3 && bytes[28] == 80);
    CHECK(decoded.identity == state.identity && decoded.epoch == 2 &&
          decoded.sequence == 5 && decoded.nextActionSequence == 3);
    for (std::size_t n = 0; n < bytes.size(); ++n)
        rejects([&] { decode_resume({bytes.begin(), bytes.begin() + n}, 2); }, Error::InvalidRequest);
    auto extra = bytes; extra.push_back(0);
    rejects([&] { decode_resume(extra, 2); }, Error::InvalidRequest);
    rejects([&] { decode_resume(bytes, 3); }, Error::EpochMismatch);
    rejects([&] { decode_resume(bytes, 2, 111); }, Error::InvalidRequest);
    rejects([&] { encode_resume(h, state, 111); }, Error::LimitExceeded);
    for (auto offset : {32, 48, 104}) {
        auto bad = bytes;
        for (int i = 0; i < (offset == 104 ? 8 : 16); ++i) bad[offset + i] = 0;
        rejects([&] { decode_resume(bad, 2); }, Error::InvalidRequest);
    }
    auto bad = bytes; bad[103] = 128;
    rejects([&] { decode_resume(bad, 2); }, Error::InvalidRequest);
    bad = bytes; bad[2] = 1;
    rejects([&] { decode_resume(bad, 2); }, Error::Incompatible);
    state.nextActionSequence = 0;
    rejects([&] { encode_resume(h, state); }, Error::InvalidRequest);
}
