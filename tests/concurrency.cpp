#include "scenario.hpp"
#include <atomic>
#include <barrier>
#include <thread>
#include <random>

void concurrent_loot() {
    Scenario s;
    auto old = s.inventory.snapshot();
    std::barrier start(20);
    std::atomic<unsigned> successes{};
    std::vector<std::jthread> threads;
    for (unsigned i = 0; i < 20; ++i) {
        threads.emplace_back([&, i] {
            Request r{{99, i + 1}, 1, Operation::Move, {move(*old, id(100), id(20))}, 0, 99};
            auto access = s.access; access.account = {90, i + 1};
            start.arrive_and_wait();
            if (s.inventory.apply(r, access).applied()) ++successes;
        });
    }
    threads.clear();
    CHECK(successes == 1);
    auto final = s.inventory.snapshot();
    CHECK(final->items.at(id(100)).quantity == 20);
    CHECK(final->placements.at(id(100)).container == id(20));
    CHECK(old->placements.at(id(100)).container == id(10));
}

void randomized_conservation() {
    Scenario s;
    std::mt19937 random(20260907);
    for (int i = 0; i < 1000; ++i) {
        auto state = s.inventory.snapshot();
        auto item = id(100 + random() % 5);
        auto target = id(random() % 2 ? 10 : 20);
        auto r = s.request(Operation::Move, {move(*state, item, target, random() % 8, random() % 8)});
        (void)s.inventory.apply(r, s.access);
        auto copy = *s.inventory.snapshot();
        validate(catalog(), copy);
        std::uint64_t mass = 0, quantity = 0;
        for (const auto& [key, c] : copy.containers) { (void)key; if (!c.state.ownerItem) mass += c.state.subtreeMassG; }
        for (const auto& [key, itemState] : copy.items) { (void)key; quantity += itemState.quantity; }
        CHECK(mass == 4100 && quantity == 62);
    }
}
