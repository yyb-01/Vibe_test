#pragma once
#include "error.hpp"
#include <chrono>

namespace astra {
// 10 commands/second, burst 20. Time comes only from the host's steady clock.
class TransactionBudget {
public:
    using Clock = std::chrono::steady_clock;
    explicit TransactionBudget(Clock::time_point now = Clock::now()) : last_(now) {}
    bool take(Clock::time_point now = Clock::now()) {
        require(now >= last_, Error::InvalidState);
        constexpr auto capacity = std::chrono::seconds(2);
        constexpr auto cost = std::chrono::milliseconds(100);
        const auto elapsed = now - last_;
        if (elapsed >= capacity - credit_) credit_ = capacity;
        else credit_ += elapsed;
        last_ = now;
        if (credit_ < cost) return false;
        credit_ -= cost;
        return true;
    }
private:
    Clock::time_point last_;
    Clock::duration credit_{std::chrono::seconds(2)};
};
}
