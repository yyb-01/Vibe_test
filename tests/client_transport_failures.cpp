#include "client_transport_fixture.hpp"
#include "shutdown.hpp"

void client_transport_failures() {
    SessionScenario f; auto baseline = transport_baseline(f);
    ClientTransport client(baseline, catalog());
    PacketHeader h; h.worldEpoch = baseline.epoch; h.messageType = MessageType::SessionResume;
    auto resume = encode_stream(encode_resume(h, baseline));
    auto token = client.open_authenticated(baseline.epoch);
    auto wrong = baseline; ++wrong.identity.account.lo;
    rejects([&] { client.receive(token, encode_stream(encode_resume(h, wrong))); }, Error::NotAccessible);
    CHECK(!client.state().connected());
    for (std::size_t cut : {std::size_t(1), std::size_t(5)}) {
        token = client.open_authenticated(baseline.epoch);
        CHECK(client.receive(token, std::span(resume).first(cut)) == cut);
        rejects([&] { client.finish(token); }, Error::InvalidRequest);
    }
    token = client.open_authenticated(baseline.epoch);
    std::thread other([&] { rejects([&] { client.receive(token, resume); }, Error::InvalidState); });
    other.join();
    CHECK(client.receive(token, resume) == resume.size());
    rejects([&] { client.receive(token, resume); }, Error::Incompatible); // Duplicate resume.
    token = client.open_authenticated(baseline.epoch);
    const std::uint8_t oversized[]{0xff, 0xff, 0xff, 0x7f};
    rejects([&] { client.receive(token, oversized); }, Error::InvalidRequest);
    token = client.open_authenticated(baseline.epoch);
    CHECK(client.receive(token, resume) == resume.size());
    const std::uint8_t shortPacket[]{1};
    rejects([&] { client.receive(token, encode_stream(shortPacket)); }, Error::InvalidRequest);
    token = client.open_authenticated(baseline.epoch);
    h.messageType = MessageType::SessionClosing;
    auto closing = encode_stream(encode_shutdown(h, 0));
    rejects([&] { client.receive(token, closing); }, Error::Incompatible); // No resume yet.
    token = client.open_authenticated(baseline.epoch);
    auto joined = resume; joined.insert(joined.end(), closing.begin(), closing.end());
    CHECK(client.receive(token, joined) == resume.size());
    CHECK(client.state().connected());
    CHECK(client.receive(token, std::span(joined).subspan(resume.size())) == closing.size());
    CHECK(!client.state().connected());
    rejects([&] { client.open_authenticated(0); }, Error::EpochMismatch);
}
