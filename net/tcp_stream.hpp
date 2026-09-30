#pragma once
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <winsock2.h>
#include <array>
#include <cstdint>
#include <span>

namespace astra::tcp {
// Windows byte transport only. Caller owns WSAStartup and the authentication boundary.
class Stream {
public:
    Stream();
    explicit Stream(SOCKET); // Takes ownership, including on configuration failure.
    ~Stream() { close(); }
    Stream(const Stream&) = delete;
    Stream& operator=(const Stream&) = delete;
    SOCKET native() const { return socket_; }
    std::size_t write(std::span<const std::uint8_t>);
    std::span<const std::uint8_t> read(std::size_t limit = 4096);
    void consume(std::size_t);
    bool eof() const { return eof_; }
    void close() noexcept;
private:
    SOCKET socket_{INVALID_SOCKET};
    std::array<std::uint8_t, 4096> buffer_{};
    std::size_t begin_{}, end_{};
    bool eof_{};
    [[noreturn]] void failed(int error, const char* operation);
};
}
