#pragma once
#include "session.hpp"
#include "stream.hpp"
#include "transport_deadlines.hpp"
#include <optional>

namespace astra {
// Trusted adapter boundary, not an authentication implementation.
// Host must outlive this object. All operations/destruction use its owner thread.
class HostTransport {
public:
    HostTransport(HostSession&, const AuthenticatedPeer&, const SessionInfo&,
                  TransportDeadlines::Clock::duration = std::chrono::seconds(30),
                  TransportDeadlines::Now = TransportDeadlines::Clock::now);
    ~HostTransport();
    HostTransport(const HostTransport&) = delete;
    HostTransport& operator=(const HostTransport&) = delete;
    std::uint64_t connection() const;
    bool poll(); // Tick before I/O; false means disconnected (including deadline expiry).
    // At most one request; caller retains suffix. Returns 0 while output is pending.
    std::size_t receive(std::span<const std::uint8_t>, const InteractionState&);
    std::span<const std::uint8_t> output() const;
    void sent(std::size_t); // Only bytes accepted by the underlying transport.
    // Separate ordered snapshot stream; revalidate with fresh observations before every write/tick.
    std::span<const std::uint8_t> snapshot_output(const InteractionState&);
    void snapshot_sent(std::size_t);
    Result shutdown(); // Drain output first; queues notice only after prepare_close is Ok.
    void finish(); // EOF, including truncation validation; always releases the peer.
    void disconnect(); // Socket failure/cancel; idempotent, discards partial output.
private:
    void start_snapshot(const InteractionState&);
    HostSession& host_;
    TransportDeadlines deadlines_;
    std::optional<StreamDecoder> input_{std::in_place};
    std::uint64_t connection_{};
    std::vector<std::uint8_t> output_;
    std::size_t sent_{};
    bool closing_{};
    std::optional<SnapshotDescriptor> snapshot_;
    std::vector<std::uint8_t> snapshot_output_;
    std::size_t snapshot_sent_{}, snapshot_page_{};
    bool snapshot_offer_{};
};
}
