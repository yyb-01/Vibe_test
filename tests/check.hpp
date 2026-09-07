#pragma once
#include "inventory.hpp"
#include <stdexcept>
#include <string>

#define CHECK(value) do { if (!(value)) throw std::runtime_error(std::string(__FILE__) + ":" + std::to_string(__LINE__) + " " #value); } while (false)
template<class F> void rejects(F action, astra::Error expected) {
    try { action(); } catch (const astra::Violation& e) { CHECK(e.code == expected); return; }
    throw std::runtime_error("Expected validation failure");
}
