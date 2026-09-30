#include "loopback.hpp"
#include <iostream>

void tcp_io(); void tcp_backpressure(); void tcp_transactions(); void tcp_reconnect(); void tcp_failures();
void tcp_fire();
int main() {
    WSADATA data{};
    if (WSAStartup(MAKEWORD(2,2), &data)) return 1;
    int result = 0;
    try {
        const std::pair<const char*, void(*)()> cases[]{
            {"TCP I/O and EOF/reset", tcp_io}, {"TCP kernel backpressure", tcp_backpressure},
            {"TCP transaction/snapshot/shutdown", tcp_transactions},
            {"TCP reconnect without duplicate save", tcp_reconnect}, {"TCP malformed/EOF/deadline cleanup", tcp_failures},
            {"TCP durable fire receipt/reconnect", tcp_fire}
        };
        for (const auto& [name, run] : cases) { run(); std::cout << "PASS " << name << '\n'; }
    } catch (const astra::Violation& e) { std::cerr << "FAIL " << astra::name(e.code) << '\n'; result = 1; }
    catch (const std::exception& e) { std::cerr << "FAIL " << e.what() << '\n'; result = 1; }
    WSACleanup(); return result;
}
