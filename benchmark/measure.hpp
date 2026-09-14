#pragma once
#include "../samples/scenario.hpp"
#include <algorithm>
#include <array>
#include <chrono>
#include <charconv>
#include <filesystem>
#include <iomanip>
#include <iostream>

inline unsigned integer(const std::filesystem::path& arg) {
    auto text = arg.string(); unsigned value{};
    auto [end, error] = std::from_chars(text.data(), text.data() + text.size(), value);
    require(error == std::errc{} && end == text.data() + text.size(), Error::InvalidRequest);
    return value;
}

template<class F> double milliseconds(F action) {
    auto start = std::chrono::steady_clock::now();
    action();
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
}
inline void print_stats(std::vector<double> samples) {
    std::sort(samples.begin(), samples.end());
    auto n = samples.size();
    std::cout << ',' << (samples[(n - 1) / 2] + samples[n / 2]) / 2
              << ',' << samples[(95 * n + 99) / 100 - 1];
}
inline void print_result(unsigned count, unsigned runs, std::size_t bytes, double startup, double shutdown,
                         const std::array<std::vector<double>, 5>& samples) {
    std::cout << "items,samples,checkpoint_bytes,startup_ms,shutdown_ms";
    for (auto stage : {"prepare", "checkpoint", "encode", "sqlite_save", "commit"})
        std::cout << ',' << stage << "_p50_ms," << stage << "_p95_ms";
    std::cout << '\n' << std::fixed << std::setprecision(6) << count << ',' << runs << ',' << bytes
              << ',' << startup << ',' << shutdown;
    for (const auto& stage : samples) print_stats(stage);
    std::cout << '\n';
}
inline Checkpoint benchmark_seed(unsigned count) {
    auto world = seed();
    for (unsigned i = 5; i < count; ++i) {
        auto root = 1000 + (i - 5) / 200;
        if (!world.containers.contains(id(root))) {
            auto c = container(root); c.kind = PlaceKind::World;
            world.containers.emplace(id(root), c);
        }
        add_item(world, 100000 + i, 1, 1, root);
    }
    return Inventory(catalog(), std::move(world), 1, 1).checkpoint();
}
