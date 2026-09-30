#pragma once
#include "transaction.hpp"

namespace astra {
struct Writer {
    std::vector<std::uint8_t> bytes;
    void put(std::uint64_t value, unsigned count) {
        for (unsigned i = 0; i < count; ++i) bytes.push_back(static_cast<std::uint8_t>(value >> (i * 8)));
    }
    void id(Id value) { put(value.hi, 8); put(value.lo, 8); }
};
struct Reader {
    const std::vector<std::uint8_t>& bytes;
    std::size_t position{};
    std::uint64_t get(unsigned count) {
        require(count <= 8 && count <= bytes.size() - position, Error::InvalidRequest);
        std::uint64_t result = 0;
        for (unsigned i = 0; i < count; ++i) result |= std::uint64_t(bytes[position++]) << (i * 8);
        return result;
    }
    Id id() { auto hi = get(8); return {hi, get(8)}; }
};
inline void check_shape(const Request& r) {
    require(!r.moves.empty() && r.moves.size() <= 8, Error::InvalidRequest);
    require(static_cast<unsigned>(r.operation) <= static_cast<unsigned>(Operation::Fire), Error::InvalidRequest);
    require(r.shot.has_value() == (r.operation == Operation::Fire), Error::InvalidRequest);
    if (r.shot) {
        validate_shot(*r.shot);
        require(r.moves.size() == 2 && r.id == Id{fire_request_namespace, r.shot->intent.fireSeq}, Error::InvalidRequest);
        for (const auto& m : r.moves)
            require(m.source == m.target && m.quantity == 1 && !m.socketId && !m.x && !m.y && !m.rotation,
                Error::InvalidRequest);
    }
}
}
