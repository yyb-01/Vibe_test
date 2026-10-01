#include "wire.hpp"

namespace astra {
Request decode(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size() >= 44 && bytes.size() <= request_payload_limit, Error::InvalidRequest);
    Reader r{bytes};
    Request result;
    result.id = r.id(); result.actionSeq = r.get(8);
    result.operation = static_cast<Operation>(r.get(1));
    auto count = r.get(1);
    if (result.operation == Operation::System) {
        require(count && count <= 32 && r.get(2) == 2, Error::InvalidRequest);
        result.baseline = r.get(8); result.interactionLease = r.get(8);
        for (std::uint64_t i = 0; i < count; ++i) result.systemRoots.push_back(r.id());
        result.newIds = r.get(2); auto size = r.get(2);
        require(size <= 512 && size == bytes.size() - r.position, Error::InvalidRequest);
        result.command.assign(bytes.begin() + r.position, bytes.end());
        check_shape(result); return result;
    }
    auto fire = result.operation == Operation::Fire;
    require(count && count <= 8 && bytes.size() == 44 + 88 * count + (fire ? shot_data_bytes : 0), Error::InvalidRequest);
    require(r.get(2) == (fire ? 1 : 0), Error::InvalidRequest);
    result.baseline = r.get(8); result.interactionLease = r.get(8);
    for (std::uint64_t i = 0; i < count; ++i) {
        MoveEntry m;
        m.item = r.id(); m.source = r.id(); m.target = r.id();
        m.itemRev = r.get(8); m.sourceRev = r.get(8); m.targetRev = r.get(8);
        m.quantity = static_cast<std::uint32_t>(r.get(4));
        m.socketId = static_cast<std::uint32_t>(r.get(4));
        m.x = static_cast<std::uint16_t>(r.get(2)); m.y = static_cast<std::uint16_t>(r.get(2));
        m.rotation = static_cast<std::uint8_t>(r.get(1));
        require(r.get(3) == 0, Error::InvalidRequest);
        result.moves.push_back(m);
    }
    if (fire) result.shot = decode_shot({bytes.begin() + r.position, bytes.end()});
    check_shape(result);
    return result;
}
}
