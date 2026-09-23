#include "check.hpp"
#include "../demo/read_line.hpp"
#include <sstream>

namespace {
class GatedInput : public std::stringbuf {
    std::future<void> ready_;
    bool loaded_{};
    int_type underflow() override {
        if (!loaded_) {
            loaded_ = true; reader = std::this_thread::get_id();
            if (ready_.wait_for(std::chrono::seconds(2)) != std::future_status::ready) return traits_type::eof();
            str("show\nquit");
        }
        return std::stringbuf::underflow();
    }
public:
    std::thread::id reader;
    explicit GatedInput(std::future<void> ready) : ready_(std::move(ready)) {}
};
}
void console_input() {
    std::promise<void> release;
    GatedInput buffer(release.get_future()); std::istream input(&buffer);
    const auto owner = std::this_thread::get_id();
    unsigned ticks = 0; bool sameThread = true;
    auto tick = [&]() noexcept {
        sameThread &= std::this_thread::get_id() == owner;
        if (++ticks == 3) release.set_value();
    };
    std::string line;
    CHECK(read_line(input, line, tick) && line == "show");
    CHECK(ticks >= 3 && sameThread && buffer.reader != owner);
    CHECK(read_line(input, line, tick) && line == "quit"); // Final line without newline.
    CHECK(!read_line(input, line, tick));
    std::istringstream emptyLine("\n");
    CHECK(read_line(emptyLine, line, tick) && line.empty());
}
