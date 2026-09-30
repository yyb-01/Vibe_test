#include "fire_scenario.hpp"
#include "fire_receipt.hpp"

void fire_receipt_checks() {
    auto data = *shot_request(seed()).shot;
    data.launch.position = {-1, -8000000000LL, 8000000000LL};
    auto r = make_fire_receipt(data.intent.fireSeq, {{Error::Ok, 42, {}}, data}, 1);
    CHECK(r.accepted->shotId == 42 && r.accepted->speed == 9000);
    CHECK(r.accepted->cell[0] == -1 && r.accepted->localPosition[0] == 124999999);
    CHECK(r.accepted->direction[0] == 32767 && r.accepted->launchTick == 100);
    PacketHeader h; h.messageType = MessageType::FireReceipt; h.worldEpoch = 1;
    auto bytes = encode_fire_receipt(h, r);
    CHECK(bytes.size() == 98 && decode_fire_receipt(bytes, 1).receipt == r);
    for (std::size_t i = 0; i < bytes.size(); ++i)
        rejects([&] { decode_fire_receipt({bytes.begin(), bytes.begin() + i}, 1); }, Error::InvalidRequest);
    rejects([&] { decode_fire_receipt(bytes, 2); }, Error::EpochMismatch);
    rejects([&] { encode_fire_receipt(h, r, 97); }, Error::LimitExceeded);
    auto bad = r; bad.accepted->localPosition[0] = 125000000;
    rejects([&] { encode_fire_receipt(h, bad); }, Error::InvalidRequest);
    bad = r; bad.accepted->direction = {};
    rejects([&] { encode_fire_receipt(h, bad); }, Error::InvalidRequest);
    bad = r; ++bad.accepted->fireSeq;
    rejects([&] { encode_fire_receipt(h, bad); }, Error::InvalidRequest);
    bytes[39] = 1;
    rejects([&] { decode_fire_receipt(bytes, 1); }, Error::InvalidRequest);
    for (auto error : {Error::Pending, Error::Busy, Error::StorageUnavailable, Error::NotAccessible}) {
        auto pending = make_fire_receipt(1, {{error, 0, {}}, {}}, 1);
        CHECK(!pending.accepted);
        auto wire = encode_fire_receipt(h, pending);
        CHECK(wire.size() == 40 && decode_fire_receipt(wire, 1).receipt == pending);
    }
    rejects([&] { make_fire_receipt(1, {{Error::Pending, 0, {}}, data}, 1); }, Error::InvalidState);
    for (auto v : {ballistics::Vector{1000, 1000, 1000}, ballistics::Vector{-2000000000, 0, 0},
                   ballistics::Vector{1154700000, -1154700000, 1154700000}}) {
        data.launch.velocity = v; data.massMg = 1000000;
        r = make_fire_receipt(1, {{Error::Ok, 42, {}}, data}, 1);
        CHECK(decode_fire_receipt(encode_fire_receipt(h, r), 1).receipt == r);
    }
}
