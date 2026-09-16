#include "stream.hpp"
#include "snapshot.hpp"
#include "wire.hpp"
#include <algorithm>

namespace astra {
std::vector<std::uint8_t> encode_stream(std::span<const std::uint8_t> bytes, std::size_t limit) {
    require(limit && limit <= snapshot_page_limit, Error::InvalidRequest);
    require(!bytes.empty() && bytes.size() <= limit, Error::LimitExceeded);
    Writer w; w.bytes.reserve(4 + bytes.size()); w.put(bytes.size(), 4);
    w.bytes.insert(w.bytes.end(), bytes.begin(), bytes.end()); return w.bytes;
}
StreamDecoder::StreamDecoder(std::size_t limit) : limit_(limit) {
    require(limit && limit <= snapshot_page_limit, Error::InvalidRequest);
}
std::size_t StreamDecoder::receive(std::span<const std::uint8_t> bytes) {
    require(!failed_ && !ended_, Error::InvalidState);
    if (complete()) return 0;
    std::size_t consumed = 0;
    try {
        while (used_ < header_.size() && consumed < bytes.size()) header_[used_++] = bytes[consumed++];
        if (used_ != header_.size()) return consumed;
        if (!size_) {
            std::uint32_t length = 0;
            for (unsigned i = 0; i < 4; ++i) length |= std::uint32_t(header_[i]) << (8 * i);
            require(length && length <= limit_, Error::InvalidRequest);
            size_ = length; data_.reserve(size_);
        }
        auto count = std::min(bytes.size() - consumed, size_ - data_.size());
        auto part = bytes.subspan(consumed, count);
        data_.insert(data_.end(), part.begin(), part.end());
        return consumed + count;
    } catch (...) { failed_ = true; throw; }
}
std::vector<std::uint8_t> StreamDecoder::take() {
    require(!failed_, Error::InvalidState); require(complete(), Error::Pending);
    auto result = std::move(data_); data_.clear(); used_ = size_ = 0; return result;
}
void StreamDecoder::finish() {
    require(!failed_, Error::InvalidState);
    if (used_ && !complete()) { failed_ = true; throw Violation{Error::InvalidRequest}; }
    ended_ = true;
}
}
