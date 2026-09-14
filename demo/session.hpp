#pragma once
#include "../samples/scenario.hpp"
#include "durable.hpp"
#include <filesystem>

struct Session {
    explicit Session(const std::filesystem::path& save = {});
    std::shared_ptr<const World> snapshot() const;
    Request request(Operation, std::vector<MoveEntry>);
    Result apply(const Request&);
    Result resolve();
    Result close();
    bool persistent() const { return bool(durable); }
private:
    std::unique_ptr<Inventory> memory;
    std::unique_ptr<DurableInventory> durable;
    Access access{{77, 1}, 1, 99, {id(10), id(20), id(30)}};
    bool pending{}, closing{};
};
