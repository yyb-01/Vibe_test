#pragma once
#include <future>
#include <istream>
#include <string>
#include <type_traits>

// Only input runs off-thread. The caller retains ownership of the session.
template<class Tick> bool read_line(std::istream& input, std::string& line, Tick tick) {
    // Unwinding with a blocked getline would wait on the async future forever.
    static_assert(std::is_nothrow_invocable_v<Tick>);
    // ponytail: one reader per line; use native cancellable I/O for remote shutdown.
    auto reading = std::async(std::launch::async, [&] { return bool(std::getline(input, line)); });
    while (reading.wait_for(std::chrono::milliseconds(10)) != std::future_status::ready) tick();
    return reading.get();
}
