#pragma once
#include "../core/session.hpp"
#include "client_state.hpp"
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
    void disconnect();
    void reconnect();
    bool connected() const { return client_.connected(); }
    Result close();
private:
    InteractionState observation() const;
    ResumeState read_resume();
    HostSession host_;
    std::uint64_t connection_{};
    ResumeState resume_;
    ClientState client_;
    std::optional<Request> request_;
    Result final_;
    std::uint64_t lease_{};
    std::uint32_t sequence_{};
};
