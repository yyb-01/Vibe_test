#pragma once
#include "transaction.hpp"
#include <map>
#include <memory>
#include <mutex>

namespace astra {
using Catalog = std::map<std::uint32_t, ItemDef>;
struct Container {
    ContainerState state;
    std::uint64_t maxMassG{UINT64_MAX}, allowedClasses{UINT64_MAX};
    PlaceKind kind{PlaceKind::Grid};
};
struct World {
    std::map<Id, ItemState> items;
    std::map<Id, Container> containers;
    std::map<Id, Placement> placements;
};
void validate(const Catalog&, World&);
std::vector<Id> ancestry(const World&, Id container);
void check_request(const World&, const Request&, const Access&);
void mutate(const Catalog&, World&, const Request&, Id created, std::uint64_t event);

// Process-local atomic state. No durable Committed acknowledgement is exposed.
class Inventory {
public:
    Inventory(Catalog catalog, World initial, std::uint64_t epoch, std::uint64_t idOrigin);
    Result apply(const Request&, const Access&);
    std::shared_ptr<const World> snapshot() const;
private:
    struct Record { std::vector<std::uint8_t> payload; Result result; };
    const Catalog catalog_;
    const std::uint64_t epoch_, origin_;
    std::uint64_t sequence_{}, nextId_{1};
    std::shared_ptr<const World> world_;
    std::map<std::pair<Id, Id>, Record> records_;
    std::map<Id, std::uint64_t> accountSeq_;
    mutable std::mutex mutex_;
};
}
