#include "check.hpp"
#include "../demo/shutdown.hpp"
#include <sstream>

void console_shutdown() {
    std::ostringstream errors;
    unsigned attempts = 0;
    // Model reconnect admission failure, storage failure, unresolved save, then recovery.
    auto close = [&]() -> astra::Result {
        switch (++attempts) {
        case 1: throw astra::Violation{astra::Error::Busy};
        case 2: throw std::runtime_error("backup unavailable");
        case 3: return {astra::Error::Pending, 0, {}};
        default: return {astra::Error::Ok, 7, {}};
        }
    };
    for (int i = 0; i < 3; ++i) CHECK(!try_shutdown(close, errors));
    auto failures = errors.str();
    CHECK(failures.find("Busy. Retry quit.") != std::string::npos);
    CHECK(failures.find("backup unavailable. Retry quit.") != std::string::npos);
    CHECK(failures.find("Pending. Retry quit.") != std::string::npos);
    CHECK(try_shutdown(close, errors) && attempts == 4 && errors.str() == failures);
}
