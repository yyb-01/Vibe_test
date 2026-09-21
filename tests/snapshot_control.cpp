#include "scenario.hpp"
#include "snapshot_control.hpp"
#include <algorithm>

void snapshot_control() {
    SnapshotOffer offer{7, {{2,3}, 2, 9, 100}, {id(10), id(20)}};
    auto bytes = encode_snapshot_offer(offer);
    CHECK(bytes.size() == 102 && decode_snapshot_offer(bytes, 2) == offer);
    for (std::size_t n = 0; n < bytes.size(); ++n)
        rejects([&] { decode_snapshot_offer({bytes.begin(), bytes.begin() + n}, 2); }, Error::InvalidRequest);
    rejects([&] { decode_snapshot_offer(bytes, 3); }, Error::EpochMismatch);
    auto bad = bytes; bad[0] = 0;
    rejects([&] { decode_snapshot_offer(bad, 2); }, Error::Incompatible);
    bad = bytes; bad[32] = 0;
    rejects([&] { decode_snapshot_offer(bad, 2); }, Error::InvalidRequest);
    bad = bytes; bad[68] = 17;
    rejects([&] { decode_snapshot_offer(bad, 2); }, Error::InvalidRequest);
    bad = bytes; std::copy_n(bytes.begin() + 70, 16, bad.begin() + 86);
    rejects([&] { decode_snapshot_offer(bad, 2); }, Error::InvalidRequest);
    bad = bytes; bad[64] = 1; bad[65] = 0; bad[66] = 32; bad[67] = 0;
    rejects([&] { decode_snapshot_offer(bad, 2); }, Error::InvalidRequest);
    offer.roots.clear();
    rejects([&] { encode_snapshot_offer(offer); }, Error::InvalidRequest);
    for (unsigned n = 1; n <= 16; ++n) offer.roots.insert(id(n));
    CHECK(encode_snapshot_offer(offer).size() == 326);
    offer.roots.insert(id(17));
    rejects([&] { encode_snapshot_offer(offer); }, Error::InvalidRequest);
    auto request = encode_snapshot_request(2); CHECK(request.size() == 32);
    decode_snapshot_request(request, 2);
    rejects([&] { decode_snapshot_request(bytes, 2); }, Error::Incompatible);
    request[28] = 1; request.push_back(0);
    rejects([&] { decode_snapshot_request(request, 2); }, Error::InvalidRequest);
}
