#include "wire.hpp"

namespace astra {
Request decode(const std::vector<std::uint8_t>& bytes) {
    require(bytes.size() >= 44 && bytes.size() <= 748, Error::InvalidRequest);
    Reader r{bytes};
    Request result;
    result.id = r.id(); result.actionSeq = r.get(8);
    result.operation = static_cast<Operation>(r.get(1));
    auto count = r.get(1);
    require(count && count <= 8 && bytes.size() == 44 + 88 * count, Error::InvalidRequest);
    require(r.get(2) == 0, Error::InvalidRequest);
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
    check_shape(result);
    return result;
}
}
