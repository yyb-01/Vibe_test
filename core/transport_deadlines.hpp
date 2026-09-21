#pragma once
#include "error.hpp"
#include <array>
#include <chrono>
#include <optional>

namespace astra {
// Fixed operation deadlines: partial progress never extends them.
class TransportDeadlines {
public:
    using Clock = std::chrono::steady_clock;
    using Now = Clock::time_point(*)();
    enum Wait { Read, Write, Snapshot };
    explicit TransportDeadlines(Clock::duration limit = std::chrono::seconds(30),
                                Now now = Clock::now) : limit_(limit), now_(now) {
        require(now_ && limit_ > Clock::duration::zero(), Error::InvalidRequest);
        sample();
    }
    void begin(Wait wait) { if (!ends_[wait]) ends_[wait] = last_ + limit_; }
    void end(Wait wait) { ends_[wait].reset(); }
    void reset() { ends_ = {}; }
    bool expired() {
        sample();
        for (const auto& end : ends_) if (end && last_ >= *end) return true;
        return false;
    }
private:
    void sample() {
        auto now = now_();
        require(now >= last_ && now <= Clock::time_point::max() - limit_, Error::InvalidState);
        last_ = now;
    }
    Clock::duration limit_;
    Now now_;
    Clock::time_point last_{Clock::time_point::min()};
    std::array<std::optional<Clock::time_point>, 3> ends_{};
};
}
