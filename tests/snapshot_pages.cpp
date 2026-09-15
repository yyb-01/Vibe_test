#include "scenario.hpp"
#include "snapshot.hpp"
#include "checkpoint_wire.hpp"

void snapshot_pages_test() {
    SnapshotData data{{id(9), 2, 17, static_cast<std::uint32_t>(snapshot_limit)}, {}};
    data.bytes.resize(snapshot_limit);
    for (std::size_t n = 0; n < data.bytes.size(); ++n) data.bytes[n] = n % 251;
    SnapshotAssembly assembly(data.descriptor);
    rejects([&] { assembly.bytes(); }, Error::Pending);
    CHECK(snapshot_pages(data.descriptor) == 33);
    auto frame = encode_snapshot_page(data, 0);
    CHECK(frame.size() == snapshot_page_limit);
    auto corrupt = frame; corrupt[44] ^= 1;
    rejects([&] { assembly.receive(corrupt); }, Error::InvalidRequest);
    for (auto length : {0u, 44u, 52u, 65535u})
        rejects([&] { assembly.receive({frame.begin(), frame.begin() + length}); }, Error::InvalidRequest);
    for (std::size_t n = snapshot_pages(data.descriptor); n; --n) {
        auto page = encode_snapshot_page(data, n - 1);
        assembly.receive(page); assembly.receive(page);
        CHECK(assembly.complete() == (n == 1));
    }
    CHECK(assembly.bytes() == data.bytes);
    auto sum = checkpoint_wire::checksum(corrupt, corrupt.size() - 8);
    for (unsigned n = 0; n < 8; ++n) corrupt[corrupt.size() - 8 + n] = sum >> (n * 8);
    rejects([&] { assembly.receive(corrupt); }, Error::InvalidRequest);
    auto wrong = data; ++wrong.descriptor.epoch;
    rejects([&] { assembly.receive(encode_snapshot_page(wrong, 0)); }, Error::InvalidRequest);
    ++wrong.descriptor.bytes;
    rejects([&] { SnapshotAssembly oversized(wrong.descriptor); }, Error::InvalidRequest);
    rejects([&] { encode_snapshot_page(data, 33); }, Error::InvalidRequest);
    CHECK(assembly.bytes() == data.bytes);
}
