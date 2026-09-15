#include "scenario.hpp"
#include "receipt.hpp"

void receipt_contract() {
    auto receipt = make_receipt({88,1}, {Error::Ok, 7, id(105)}, 2);
    PacketHeader header; header.worldEpoch = 2; header.messageType = MessageType::InventoryReceipt;
    auto bytes = encode_receipt(header, receipt);
    CHECK(bytes.size() == 70 && bytes[2] == 2 && bytes[28] == 38);
    CHECK(bytes[32] == 88 && bytes[40] == 1 && bytes[48] == 1);
    CHECK(bytes[49] == 0 && bytes[50] == 0 && bytes[51] == 0);
    CHECK(bytes[52] == 7 && bytes[60] == 2 && bytes[68] == 0 && bytes[69] == 0);
    CHECK(decode_receipt(bytes, 2).receipt == receipt);
    for (std::size_t n = 0; n < bytes.size(); ++n)
        rejects([&] { decode_receipt({bytes.begin(), bytes.begin() + n}, 2); }, Error::InvalidRequest);
    for (auto offset : {0, 2, 28, 30, 48, 49, 51, 68}) {
        auto bad = bytes; bad[offset] = 255;
        rejects([&] { decode_receipt(bad, 2); }, offset < 4 ? Error::Incompatible : Error::InvalidRequest);
    }
    auto bad = bytes; bad[60] = 3;
    rejects([&] { decode_receipt(bad, 2); }, Error::EpochMismatch);
    rejects([&] { decode_receipt(bytes, 3); }, Error::EpochMismatch);
    rejects([&] { decode_packet(bytes, 2); }, Error::Incompatible);
    for (std::size_t budget : {0u, 31u, 69u})
        rejects([&] { encode_receipt(header, receipt, budget); }, Error::LimitExceeded);
    rejects([&] { decode_receipt(bytes, 2, 69); }, Error::InvalidRequest);
    bytes.push_back(0);
    rejects([&] { decode_receipt(bytes, 2); }, Error::InvalidRequest);
    header.worldEpoch = 3;
    rejects([&] { encode_receipt(header, receipt); }, Error::EpochMismatch);
}

void receipt_validation() {
    auto receipt = make_receipt(id(1), {Error::Ok, 1, {}}, 1);
    for (int n = 0; n < 6; ++n) {
        auto bad = receipt;
        if (n == 0) bad.requestId = {};
        if (n == 1) bad.durableWorldEpoch = 0;
        if (n == 2) bad.commitSequence = 0;
        if (n == 3) bad.reason = ClientReason::Busy;
        if (n == 4) bad.status = static_cast<TransactionStatus>(255);
        if (n == 5) bad.durableWorldEpoch = UINT64_MAX;
        rejects([&] { validate_receipt(bad); }, Error::InvalidRequest);
    }
    for (auto status : {TransactionStatus::Pending, TransactionStatus::Rejected, TransactionStatus::Resolving}) {
        auto bad = receipt; bad.status = status;
        rejects([&] { validate_receipt(bad); }, Error::InvalidRequest);
    }
}
