#include "wire.hpp"

namespace astra {
std::vector<std::uint8_t> encode(const Request& r) {
    check_shape(r);
    Writer w;
    w.bytes.reserve(44 + 88 * r.moves.size());
    w.id(r.id); w.put(r.actionSeq, 8);
    auto system = r.operation == Operation::System;
    w.put(static_cast<unsigned>(r.operation), 1); w.put(system ? r.systemRoots.size() : r.moves.size(), 1);
    w.put(system ? 2 : r.shot ? 1 : 0, 2); w.put(r.baseline, 8); w.put(r.interactionLease, 8);
    if (system) {
        for (auto root : r.systemRoots) w.id(root);
        w.put(r.newIds, 2); w.put(r.command.size(), 2);
        w.bytes.insert(w.bytes.end(), r.command.begin(), r.command.end());
        return w.bytes;
    }
    for (const auto& m : r.moves) {
        w.id(m.item); w.id(m.source); w.id(m.target);
        w.put(m.itemRev, 8); w.put(m.sourceRev, 8); w.put(m.targetRev, 8);
        w.put(m.quantity, 4); w.put(m.socketId, 4);
        w.put(m.x, 2); w.put(m.y, 2); w.put(m.rotation, 1); w.put(0, 3);
    }
    if (r.shot) {
        auto shot = encode_shot(*r.shot);
        w.bytes.insert(w.bytes.end(), shot.begin(), shot.end());
    }
    return w.bytes;
}
}
