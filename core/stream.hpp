#pragma once
#include "packet.hpp"
#include <array>
#include <span>

namespace astra {
// Four-byte little-endian length, then one unchanged packet or snapshot page.
std::vector<std::uint8_t> encode_stream(std::span<const std::uint8_t>,
                                       std::size_t limit = datagram_limit);
// One decoder per authenticated logical stream. Never reuse across connections.
class StreamDecoder {
public:
    explicit StreamDecoder(std::size_t limit = datagram_limit);
    // Consumes at most one frame. Caller retains the suffix and takes completed frames.
    std::size_t receive(std::span<const std::uint8_t>);
    bool complete() const { return !failed_ && size_ && data_.size() == size_; }
    std::vector<std::uint8_t> take();
    // EOF: partial frames fail; an already complete frame remains available to take.
    void finish();
private:
    const std::size_t limit_;
    std::array<std::uint8_t, 4> header_{};
    std::size_t used_{}, size_{};
    std::vector<std::uint8_t> data_;
    bool failed_{}, ended_{};
};
}
