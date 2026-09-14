#pragma once
#include "measure.hpp"
#include "async_store.hpp"
#include "sqlite.hpp"

template<class F> double poll(F action) {
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(30);
    double peak = 0; bool done;
    do {
        peak = std::max(peak, milliseconds([&] { done = action(); }));
        require(std::chrono::steady_clock::now() < deadline, Error::StorageUnavailable);
        if (!done) std::this_thread::sleep_for(std::chrono::milliseconds(1));
    } while (!done);
    return peak;
}
inline void benchmark_async(const std::filesystem::path& path, unsigned count, unsigned runs) {
    auto seed = benchmark_seed(count);
    std::unique_ptr<DurableInventory> inventory; AsyncStore* queue;
    auto startup = milliseconds([&] {
        auto store = std::make_unique<AsyncStore>([path] { return std::make_unique<SQLiteStore>(path); }, seed);
        queue = store.get(); poll([&] { return queue->ready(); });
        inventory = std::make_unique<DurableInventory>(std::move(store), seed);
    });
    Access access{{77, 1}, inventory->epoch(), 99, {id(10), id(20)}};
    std::array<std::vector<double>, 3> samples; std::size_t bytes = 0;
    for (unsigned n = 1; n <= runs + 1; ++n) {
        auto view = copy_roots(inventory->snapshot_roots(access.roots).roots, access.roots);
        Request request{{88, n}, n, Operation::Move, {move(view, id(100), id(n % 2 ? 20 : 10))}, 0, 99};
        Result result; std::array<double, 3> elapsed;
        elapsed[2] = milliseconds([&] {
            elapsed[0] = milliseconds([&] { result = inventory->apply(request, access); });
            require(result.code == Error::Pending, Error::InvalidState);
            bytes = std::max(bytes, queue->status().bytes);
            elapsed[1] = poll([&] { result = inventory->resolve(); return result.code != Error::Pending; });
        });
        require(result.applied() && result.sequence == n, Error::InvalidState);
        if (n > 1) for (unsigned i = 0; i < samples.size(); ++i) samples[i].push_back(elapsed[i]);
    }
    Result closed;
    auto shutdown = milliseconds([&] { poll([&] { closed = inventory->close(); return closed.code != Error::Pending; }); });
    require(closed.applied(), Error::StorageUnavailable);
    SQLiteStore disk(path);
    auto loaded = disk.acquire(seed);
    require(loaded.checkpoint.sequence == runs + 1 && loaded.checkpoint.world == *inventory->snapshot(), Error::InvalidState);
    disk.close();
    std::cout << "items,samples,message_budget_bytes,startup_ms,shutdown_ms";
    for (auto stage : {"submit", "resolve_peak", "roundtrip"})
        std::cout << ',' << stage << "_p50_ms," << stage << "_p95_ms";
    std::cout << '\n' << std::fixed << std::setprecision(6) << count << ',' << runs << ',' << bytes << ',' << startup << ',' << shutdown;
    for (const auto& stage : samples) print_stats(stage);
    std::cout << '\n';
}
