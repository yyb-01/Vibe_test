#include "scenario.hpp"
#include "checkpoint_delta.hpp"
#include "checkpoint_wire.hpp"

void checkpoint_deltas() {
    Scenario s;
    auto check = [&](const Request& request) {
        auto previous = s.inventory.checkpoint();
        auto prepared = s.inventory.prepare(request, s.access);
        CHECK(prepared.changes);
        auto delta = s.inventory.checkpoint_delta(prepared.changes);
        auto bytes = encode_delta(delta);
        auto decoded = decode_delta(bytes);
        CHECK(encode_delta(decoded) == bytes);
        apply_checkpoint_delta(previous, decoded);
        CHECK(encode_checkpoint(previous) == encode_checkpoint(s.inventory.checkpoint_after(prepared.changes)));
        CHECK(s.inventory.commit(prepared.changes).code == delta.changes.outcome.code);
        return delta;
    };
    auto part = move(*s.inventory.snapshot(), id(100), id(20)); part.quantity = 7;
    auto split = check(s.request(Operation::Split, {part}));
    auto merged = check(s.request(Operation::Merge,
        {move(*s.inventory.snapshot(), split.changes.outcome.created, id(10), 0)}));
    CHECK(!merged.changes.placements.at(split.changes.outcome.created).after);
    auto rejected = check(s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20), UINT16_MAX)}));
    CHECK(!rejected.changes.outcome.applied() && rejected.changes.items.empty());
    auto bytes = encode_delta(split);
    auto reseal = [](auto& data) {
        auto sum = checkpoint_wire::checksum(data, data.size() - 8);
        for (unsigned n = 0; n < 8; ++n) data[data.size() - 8 + n] = static_cast<std::uint8_t>(sum >> (8 * n));
    };
    auto invalid = bytes; invalid[4] = 2; reseal(invalid);
    rejects([&] { decode_delta(invalid); }, Error::InvalidState);
    invalid = bytes;
    invalid[152 + split.changes.payload.size() + 16 * split.changes.roots.size()] = 0;
    reseal(invalid);
    rejects([&] { decode_delta(invalid); }, Error::InvalidState);
    for (std::size_t n = 0; n < bytes.size(); ++n) {
        auto corrupt = bytes; corrupt[n] ^= 1;
        rejects([&] { decode_delta(corrupt); }, Error::InvalidState);
        std::vector<std::uint8_t> cut(bytes.begin(), bytes.begin() + n);
        rejects([&] { decode_delta(cut); }, Error::InvalidState);
    }
    auto original = Inventory(catalog(), seed(), 1, 1).checkpoint();
    auto conflict = split;
    ++conflict.changes.items.at(id(100)).before->quantity;
    rejects([&] { apply_checkpoint_delta(original, conflict); }, Error::InvalidState);
    conflict = split; ++conflict.changes.epoch;
    rejects([&] { apply_checkpoint_delta(original, conflict); }, Error::InvalidState);
}
