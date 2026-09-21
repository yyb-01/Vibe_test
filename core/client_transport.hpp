#pragma once
#include "client_state.hpp"
#include "stream.hpp"
#include "transport_deadlines.hpp"
#include <thread>

namespace astra {
// One persistent adapter per client; owner thread only. No sockets/authentication.
class ClientTransport {
public:
    // Trusted identity/baseline, never inferred from incoming bytes.
    ClientTransport(const ResumeState&, Catalog,
                    TransportDeadlines::Clock::duration = std::chrono::seconds(30),
                    TransportDeadlines::Now = TransportDeadlines::Clock::now);
    ClientTransport(const ClientTransport&) = delete;
    ClientTransport& operator=(const ClientTransport&) = delete;
    // Call only after platform authentication; first frame must be SessionResume.
    std::uint64_t open_authenticated(std::uint64_t epoch);
    const ClientState& state() const;
    bool poll(std::uint64_t token); // Tick before I/O; stale tokens return false.
    void submit(std::uint64_t token, const Request&);
    void retry(std::uint64_t token, Id);
    void forget(Id);
    void timeout(std::uint64_t token, Id);
    std::span<const std::uint8_t> output(std::uint64_t token) const;
    void sent(std::uint64_t token, std::size_t);
    std::size_t receive(std::uint64_t token, std::span<const std::uint8_t>);
    void finish(std::uint64_t token);
    void disconnect(std::uint64_t token); // Stale callback is a no-op.
    void request_snapshot(std::uint64_t token);
    std::uint64_t snapshot_lease(std::uint64_t token) const;
    std::size_t receive_snapshot(std::uint64_t token, std::span<const std::uint8_t>);
    void finish_snapshot(std::uint64_t token);
private:
    void owner() const;
    void check(std::uint64_t token) const;
    ClientState state_;
    TransportDeadlines deadlines_;
    std::optional<StreamDecoder> input_;
    std::vector<std::uint8_t> output_;
    std::size_t sent_{};
    std::uint64_t epoch_{}, generation_{};
    bool active_{};
    std::optional<StreamDecoder> snapshot_input_;
    std::uint64_t lease_{};
    bool snapshot_requested_{}, snapshot_offer_{};
    const std::thread::id owner_{std::this_thread::get_id()};
};
}
