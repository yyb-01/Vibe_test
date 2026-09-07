#pragma once
#include <cstddef>

namespace allocation_probe {
// Thread-local test instrumentation; never linked into the game/demo library.
class Scope {
public:
    explicit Scope(std::size_t failAfter);
    ~Scope();
    Scope(const Scope&) = delete;
    Scope& operator=(const Scope&) = delete;
    std::size_t count() const;
};
}
