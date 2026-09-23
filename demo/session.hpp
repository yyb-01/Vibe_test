#pragma once
#include "../samples/scenario.hpp"
#include "durable.hpp"
#include "client.hpp"
#include <filesystem>

struct Session {
    explicit Session(const std::filesystem::path& save = {}, bool clientMode = false);
    std::shared_ptr<const World> snapshot();
    Request request(Operation, std::vector<MoveEntry>);
    Result apply(const Request&, bool wait = true);
    void disconnect();
    void reconnect();
    Result resolve();
    Result close();
    void tick() { if (client && !closing) client->tick(); }
    bool persistent() const { return bool(durable); }
private:
    std::unique_ptr<Inventory> memory;
    std::unique_ptr<DurableInventory> durable;
    std::unique_ptr<ConsoleClient> client;
    std::uint64_t nextRequest{1};
    Access access{{77, 1}, 1, 99, {id(10), id(20), id(30)}};
    bool pending{}, closing{};
};
