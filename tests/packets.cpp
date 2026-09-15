#include "scenario.hpp"
#include "packet.hpp"

void packet_contract() {
    Scenario s;
    auto request = s.request(Operation::Move, {move(*s.inventory.snapshot(), id(100), id(20))});
    PacketHeader header;
    header.worldEpoch = s.access.epoch;
    header.sequence = 0x12345678; header.ackSequence = UINT32_MAX;
    header.ackBits = 0x80000001; header.senderTick = UINT32_MAX;
    auto bytes = encode_packet(header, request);
    CHECK(bytes.size() == 164 && bytes[12] == 0x78 && bytes[15] == 0x12);
    CHECK(bytes[28] == 132 && bytes[29] == 0 && bytes[30] == 0);
    auto packet = decode_packet(bytes, header.worldEpoch);
    header.payloadBytes = 132;
    CHECK(packet.header == header && encode(packet.request) == encode(request));
    auto result = s.inventory.apply(packet.request, s.access);
    CHECK(result.applied());
    CHECK(s.inventory.apply(decode_packet(bytes, header.worldEpoch).request, s.access).sequence == result.sequence);
    rejects([&] { decode_packet(bytes, header.worldEpoch + 1); }, Error::EpochMismatch);
    for (std::size_t n = 0; n < bytes.size(); ++n) {
        rejects([&] { decode_packet({bytes.begin(), bytes.begin() + n}, header.worldEpoch); }, Error::InvalidRequest);
    }
    for (auto offset : {0, 2, 28, 30, 58}) {
        auto bad = bytes; bad[offset] = 255;
        rejects([&] { decode_packet(bad, header.worldEpoch); },
                offset < 4 ? Error::Incompatible : Error::InvalidRequest);
    }
    rejects([&] { encode_packet(header, request, bytes.size() - 1); }, Error::LimitExceeded);
    rejects([&] { decode_packet(bytes, header.worldEpoch, bytes.size() - 1); }, Error::InvalidRequest);
    bytes.push_back(0);
    rejects([&] { decode_packet(bytes, header.worldEpoch); }, Error::InvalidRequest);
    request.moves.resize(8, request.moves[0]);
    CHECK(encode_packet(header, request).size() == 780);
}

void packet_window() {
    PacketWindow w;
    CHECK(w.observe(UINT32_MAX - 1)); CHECK(w.observe(0));
    CHECK(w.sequence == 0 && w.bits == 2);
    CHECK(w.observe(UINT32_MAX)); CHECK(w.bits == 3);
    CHECK(!w.observe(UINT32_MAX) && !w.observe(0));
    CHECK(w.observe(32) && w.bits == 0x80000000u);
    CHECK(!w.observe(0)); CHECK(w.observe(1));
    CHECK(!w.observe(UINT32_MAX));
    CHECK(w.observe(65) && w.bits == 0);
    auto before = w;
    CHECK(!w.observe(65 + 0x80000000u));
    CHECK(w.sequence == before.sequence && w.bits == before.bits);
    CHECK(serial_newer(0, UINT32_MAX));
    CHECK(!serial_newer(UINT32_MAX, 0) && !serial_newer(0x80000000u, 0));
}
