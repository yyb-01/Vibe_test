#pragma once
#include "transaction.hpp"
#include <exception>
#include <ostream>

// Keep the session alive after a failed interactive quit; EOF is handled by the caller.
template<class Close> bool try_shutdown(Close close, std::ostream& errors) {
    try {
        auto result = close();
        if (result.applied()) return true;
        errors << "Shutdown incomplete: " << astra::name(result.code);
    } catch (const astra::Violation& e) {
        errors << "Shutdown incomplete: " << astra::name(e.code);
    } catch (const std::exception& e) {
        errors << "Shutdown incomplete: " << e.what();
    }
    errors << ". Retry quit.\n";
    return false;
}
