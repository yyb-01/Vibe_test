#include "scenario.hpp"

void wire_contract() {
    Scenario s;
    auto r = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20))});
    auto bytes = encode(r);
    CHECK(bytes.size() == 132);
    CHECK(bytes[0] == 88 && bytes[8] == 1 && bytes[16] == 1);
    CHECK(bytes[24] == 0 && bytes[25] == 1);
    CHECK(encode(decode(bytes)) == bytes);
    for (std::size_t n = 0; n < bytes.size(); ++n) {
        auto cut = std::vector<std::uint8_t>(bytes.begin(), bytes.begin() + n);
        rejects([&] { (void)decode(cut); }, Error::InvalidRequest);
    }
    for (auto position : {24, 25, 26, 131}) {
        auto corrupt = bytes; corrupt[position] = 255;
        rejects([&] { (void)decode(corrupt); }, Error::InvalidRequest);
    }
    bytes.push_back(0);
    rejects([&] { (void)decode(bytes); }, Error::InvalidRequest);
    r.moves.resize(8, r.moves[0]);
    CHECK(encode(r).size() == 748);
    r.moves.push_back(r.moves[0]);
    rejects([&] { (void)encode(r); }, Error::InvalidRequest);
}
