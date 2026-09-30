#include "check.hpp"
#include "fire_intent.hpp"

void fire_intent_contract() {
    using namespace astra;
    FireIntent intent{0x04030201, 0x08070605, 0x0c0b0a09, 0x0e0d, 0x1211100f, 0x1413,
        0x1c1b1a1918171615, -2, -16384, trigger_on, 12};
    std::vector<std::uint8_t> golden;
    for (std::uint8_t n = 1; n <= 28; ++n) golden.push_back(n);
    for (auto n : {254, 255, 0, 192, 1, 12}) golden.push_back(static_cast<std::uint8_t>(n));
    CHECK(golden.size() == 34 && encode_fire_intent(intent) == golden);
    CHECK(decode_fire_intent(golden) == intent);
    for (std::size_t n = 0; n < golden.size(); ++n) {
        std::vector<std::uint8_t> truncated(golden.begin(), golden.begin() + n);
        rejects([&] { decode_fire_intent(truncated); }, Error::InvalidRequest);
    }
    auto invalid = golden; invalid.push_back(0);
    rejects([&] { decode_fire_intent(invalid); }, Error::InvalidRequest);
    for (auto byte : {0, 3, 255}) {
        invalid = golden; invalid[32] = static_cast<std::uint8_t>(byte);
        rejects([&] { decode_fire_intent(invalid); }, Error::InvalidRequest);
    }
    invalid = golden; invalid[33] = 13;
    rejects([&] { decode_fire_intent(invalid); }, Error::InvalidRequest);
    auto bad = intent; bad.weaponNetId = 0;
    rejects([&] { encode_fire_intent(bad); }, Error::InvalidRequest);
    bad = intent; bad.assemblyRevision = 0;
    rejects([&] { encode_fire_intent(bad); }, Error::InvalidRequest);
    bad = intent; bad.aimPitch = 16385;
    rejects([&] { encode_fire_intent(bad); }, Error::InvalidRequest);
    intent.buttons = trigger_off; intent.aimYaw = INT16_MIN; intent.aimPitch = 16384;
    intent.inputSeq = intent.fireSeq = 0; intent.generation = 0;
    CHECK(decode_fire_intent(encode_fire_intent(intent)) == intent);
}
