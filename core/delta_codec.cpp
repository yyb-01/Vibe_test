#include "delta_wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode_delta(const CheckpointDelta& d) {
    const auto& c = d.changes;
    require(c.payload.size() <= 748 && c.roots.size() <= 4096, Error::LimitExceeded);
    Writer w; w.put(0x41544c44, 4); w.put(1, 4);
    w.id(c.account); w.id(c.requestId);
    for (auto n : {c.epoch, c.actionSeq, c.event, d.origin, d.sequence, d.nextId, d.nextEvent}) w.put(n, 8);
    w.put(static_cast<unsigned>(c.outcome.code), 4); w.put(c.outcome.sequence, 8); w.id(c.outcome.created);
    w.put(c.payload.size(), 4); w.bytes.insert(w.bytes.end(), c.payload.begin(), c.payload.end());
    w.put(c.roots.size(), 4); for (auto id : c.roots) w.id(id);
    delta_wire::put(w, c.items, 65536); delta_wire::put(w, c.containers, 4096);
    delta_wire::put(w, c.placements, 65536);
    w.put(checkpoint_wire::checksum(w.bytes, w.bytes.size()), 8);
    return std::move(w.bytes);
}
CheckpointDelta decode_delta(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size() >= 152 && bytes.size() <= checkpoint_byte_limit, Error::InvalidState);
    Reader tail{bytes, bytes.size() - 8};
    require(tail.get(8) == checkpoint_wire::checksum(bytes, bytes.size() - 8), Error::InvalidState);
    Reader r{bytes}; require(r.get(4) == 0x41544c44 && r.get(4) == 1, Error::InvalidState);
    CheckpointDelta d; auto& c = d.changes;
    c.account = r.id(); c.requestId = r.id(); c.epoch = r.get(8); c.actionSeq = r.get(8); c.event = r.get(8);
    d.origin = r.get(8); d.sequence = r.get(8); d.nextId = r.get(8); d.nextEvent = r.get(8);
    c.outcome.code = static_cast<Error>(r.get(4)); c.outcome.sequence = r.get(8); c.outcome.created = r.id();
    auto size = r.get(4); require(size <= 748 && size <= bytes.size() - r.position, Error::InvalidState);
    c.payload.assign(bytes.begin() + r.position, bytes.begin() + r.position + size); r.position += size;
    size = r.get(4); require(size <= 4096, Error::LimitExceeded);
    for (; size; --size) c.roots.push_back(r.id());
    delta_wire::get(r, c.items, 65536, checkpoint_wire::item);
    delta_wire::get(r, c.containers, 4096, checkpoint_wire::container);
    delta_wire::get(r, c.placements, 65536, checkpoint_wire::placement);
    require(r.position == bytes.size() - 8, Error::InvalidState);
    return d;
}
}
