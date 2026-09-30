#include "magazine_fixture.hpp"
#include "checkpoint_wire.hpp"

namespace {
std::vector<std::uint8_t> with_version(std::vector<std::uint8_t> bytes, std::uint8_t version) {
    bytes[4] = version;
    auto sum = checkpoint_wire::checksum(bytes, bytes.size() - 8);
    for (unsigned i = 0; i < 8; ++i) bytes[bytes.size() - 8 + i] = static_cast<std::uint8_t>(sum >> (8 * i));
    return bytes;
}
}
void ammunition_checkpoint_versions() {
    Scenario ordinary; auto legacy = ordinary.inventory.checkpoint();
    auto bytes = encode_checkpoint(legacy); CHECK(bytes[4] == 1);
    CHECK(encode_checkpoint(decode_checkpoint(bytes)) == bytes);
    // A previously applied Fire record without new container roles remains readable as v2.
    auto fire = shot_request(legacy.world); legacy.sequence = 1; legacy.nextEvent = 2;
    legacy.world.items.at(id(100)).quantity = 19; ++legacy.world.items.at(id(100)).revision;
    legacy.world.items.at(id(104)).durability = 65530; ++legacy.world.items.at(id(104)).revision;
    validate(legacy.catalog, legacy.world);
    legacy.requests.push_back({ordinary.access.account, fire.id, 1, encode(fire), {Error::Ok, 1, {}}});
    bytes = encode_checkpoint(legacy); CHECK(bytes[4] == 2);
    Inventory old(decode_checkpoint(bytes)); CHECK(old.apply(fire, ordinary.access).sequence == 1);
    for (auto checkpoint : {fire_checkpoint(), magazine_checkpoint()}) {
        bytes = encode_checkpoint(checkpoint); CHECK(bytes[4] == 3);
        CHECK(encode_checkpoint(decode_checkpoint(bytes)) == bytes);
        for (auto version : {1, 2, 4}) {
            auto wrong = with_version(bytes, version);
            rejects([&] { decode_checkpoint(wrong); }, Error::InvalidState);
        }
    }
}
