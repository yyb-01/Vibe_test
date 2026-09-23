#pragma once
#include "../core/session.hpp"
#include "transport_loop.hpp"
#include "../samples/scenario.hpp"

// In-process protocol exercise with fixed trusted observations, not network authentication.
class ConsoleClient {
public:
    explicit ConsoleClient(DurableInventory&);
    std::shared_ptr<const World> snapshot();
    std::uint64_t lease() const { return lease_; }
    std::uint64_t next_action_sequence();
    Result apply(const Request&);
    Result retry();
    void tick();
    void disconnect();
    void reconnect();
    bool connected() const { return client_.state().connected(); }
    Result close();
private:
    InteractionState observation() const;
    ResumeState read_resume();
    void exchange(bool snapshot = false, bool closing = false);
    Result result();
    DurableInventory& inventory_; // Host diagnostics only; never the client view.
    HostSession host_;
    std::unique_ptr<HostTransport> transport_;
    std::uint64_t token_{};
    ResumeState resume_;
    ClientTransport client_;
    std::optional<Request> request_;
    std::uint64_t lease_{};
};
