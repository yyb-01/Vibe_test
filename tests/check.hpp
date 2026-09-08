#pragma once
#include "inventory.hpp"
#include <stdexcept>
#include <string>
#include <chrono>
#include <thread>

#define CHECK(value) do { if (!(value)) throw std::runtime_error(std::string(__FILE__) + ":" + std::to_string(__LINE__) + " " #value); } while (false)
template<class F> void rejects(F action, astra::Error expected) {
    try { action(); } catch (const astra::Violation& e) { CHECK(e.code == expected); return; }
    throw std::runtime_error("Expected validation failure");
}
template<class F> void eventually(F done) {
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
    while (!done()) { CHECK(std::chrono::steady_clock::now() < deadline); std::this_thread::yield(); }
}
