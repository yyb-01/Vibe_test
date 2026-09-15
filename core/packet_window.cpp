#include "packet.hpp"

namespace astra {
bool PacketWindow::observe(std::uint32_t incoming) {
    if (!initialized) { initialized = true; sequence = incoming; bits = 0; return true; }
    if (serial_newer(incoming, sequence)) {
        auto gap = std::uint32_t(incoming - sequence);
        bits = gap > 32 ? 0 : (gap == 32 ? 0 : bits << gap) | (1u << (gap - 1));
        sequence = incoming;
        return true;
    }
    auto age = std::uint32_t(sequence - incoming);
    if (!age || age > 32) return false;
    auto bit = std::uint32_t(1) << (age - 1);
    if (bits & bit) return false;
    bits |= bit;
    return true;
}
}
