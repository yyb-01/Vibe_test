#include "tcp_stream.hpp"
#include "../core/error.hpp"
#include <algorithm>
#include <climits>
#include <system_error>

namespace astra::tcp {
Stream::Stream() : Stream(::socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)) {}
Stream::Stream(SOCKET socket) : socket_(socket) {
    if (socket_ == INVALID_SOCKET) failed(WSAGetLastError(), "socket");
    u_long mode = 1;
    if (ioctlsocket(socket_, FIONBIO, &mode) == SOCKET_ERROR) failed(WSAGetLastError(), "FIONBIO");
    BOOL enabled = TRUE;
    if (setsockopt(socket_, IPPROTO_TCP, TCP_NODELAY, reinterpret_cast<const char*>(&enabled), sizeof(enabled)))
        failed(WSAGetLastError(), "TCP_NODELAY");
}
void Stream::close() noexcept {
    if (socket_ != INVALID_SOCKET) closesocket(socket_);
    socket_ = INVALID_SOCKET; begin_ = end_ = 0; eof_ = true;
}
void Stream::failed(int error, const char* operation) {
    close(); throw std::system_error(error, std::system_category(), operation);
}
std::size_t Stream::write(std::span<const std::uint8_t> bytes) {
    require(socket_ != INVALID_SOCKET, Error::InvalidState);
    if (bytes.empty()) return 0;
    int n = ::send(socket_, reinterpret_cast<const char*>(bytes.data()),
                   static_cast<int>(std::min(bytes.size(), std::size_t(INT_MAX))), 0);
    if (n != SOCKET_ERROR) return static_cast<std::size_t>(n);
    int error = WSAGetLastError();
    if (error == WSAEWOULDBLOCK) return 0;
    failed(error, "send");
}
std::span<const std::uint8_t> Stream::read(std::size_t limit) {
    require(socket_ != INVALID_SOCKET, Error::InvalidState);
    require(limit > 0 && limit <= buffer_.size(), Error::InvalidRequest);
    if (begin_ == end_ && !eof_) {
        int n = ::recv(socket_, reinterpret_cast<char*>(buffer_.data()), static_cast<int>(limit), 0);
        if (n == SOCKET_ERROR) {
            int error = WSAGetLastError();
            if (error == WSAEWOULDBLOCK) return {};
            failed(error, "recv");
        }
        begin_ = 0; end_ = static_cast<std::size_t>(n); eof_ = n == 0;
    }
    return std::span(buffer_).subspan(begin_, std::min(limit, end_ - begin_));
}
void Stream::consume(std::size_t n) {
    require(n <= end_ - begin_, Error::InvalidRequest); begin_ += n;
}
}
