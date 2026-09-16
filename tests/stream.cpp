#include "scenario.hpp"
#include "stream.hpp"
#include "snapshot.hpp"

void stream_frames() {
    const std::vector<std::uint8_t> payload{1,2,3,4,5}; auto wire = encode_stream(payload);
    CHECK(wire[0] == 5 && wire[1] == 0 && wire.size() == 9);
    for (std::size_t split = 0; split <= wire.size(); ++split) {
        StreamDecoder d; auto bytes = std::span(wire);
        CHECK(d.receive(bytes.first(split)) == split);
        CHECK(d.receive(bytes.subspan(split)) == wire.size() - split);
        CHECK(d.complete() && d.take() == payload); d.finish();
        rejects([&] { d.receive(wire); }, Error::InvalidState);
    }
    auto joined = wire; joined.insert(joined.end(), wire.begin(), wire.end());
    StreamDecoder d; CHECK(d.receive(joined) == wire.size());
    CHECK(d.receive(wire) == 0 && d.take() == payload);
    CHECK(d.receive(std::span(joined).subspan(wire.size())) == wire.size());
    d.finish(); CHECK(d.take() == payload);
    for (std::size_t n = 1; n < wire.size(); ++n) {
        StreamDecoder partial; partial.receive(std::span(wire).first(n));
        rejects([&] { partial.take(); }, Error::Pending);
        rejects([&] { partial.finish(); }, Error::InvalidRequest);
        rejects([&] { partial.receive(wire); }, Error::InvalidState);
    }
    for (auto header : {std::vector<std::uint8_t>{0,0,0,0}, {177,4,0,0}, {255,255,255,255}}) {
        StreamDecoder bad;
        rejects([&] { bad.receive(header); }, Error::InvalidRequest);
        rejects([&] { bad.take(); }, Error::InvalidState);
    }
    std::vector<std::uint8_t> maximum(snapshot_page_limit, 42);
    auto big = encode_stream(maximum, snapshot_page_limit); StreamDecoder page(snapshot_page_limit);
    for (auto byte : big) CHECK(page.receive(std::span(&byte, 1)) == 1);
    CHECK(page.take() == maximum); page.finish();
    rejects([&] { encode_stream(maximum); }, Error::LimitExceeded);
    maximum.push_back(0);
    rejects([&] { encode_stream(maximum, snapshot_page_limit); }, Error::LimitExceeded);
    rejects([&] { StreamDecoder invalid(0); }, Error::InvalidRequest);
    rejects([&] { StreamDecoder invalid(snapshot_page_limit + 1); }, Error::InvalidRequest);
    rejects([&] { encode_stream({}); }, Error::LimitExceeded);
}
