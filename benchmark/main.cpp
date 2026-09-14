#include "measure.hpp"
#include "sqlite.hpp"
#include "async.hpp"
#ifdef _WIN32
int wmain(int argc, wchar_t** argv) {
#else
int main(int argc, char** argv) {
#endif
    try {
        require(argc == 4 || (argc == 5 && std::filesystem::path(argv[4]) == "--async"), Error::InvalidRequest);
        auto path = world_path(argv[1]);
        auto count = integer(argv[2]), runs = integer(argv[3]);
        require(count >= 5 && count <= 60000 && runs >= 3 && runs <= 1000, Error::InvalidRequest);
        require(!std::filesystem::exists(path), Error::InvalidState);
        if (argc == 5) { benchmark_async(path, count, runs); return 0; }
        auto initial = benchmark_seed(count);
        SQLiteStore store(path); StoredWorld loaded;
        auto startup = milliseconds([&] { loaded = store.acquire(initial); });
        Access access{{77, 1}, loaded.checkpoint.epoch, 99, {id(10), id(20)}};
        Inventory memory(std::move(loaded.checkpoint));
        std::array<std::vector<double>, 5> samples;
        std::vector<std::uint8_t> bytes;
        for (unsigned n = 1; n <= runs + 1; ++n) {
            auto view = copy_roots(memory.snapshot_roots(access.roots).roots, access.roots);
            Request request{{88, n}, n, Operation::Move,
                {move(view, id(100), id(n % 2 ? 20 : 10))}, 0, 99};
            Preparation prepared; Checkpoint checkpoint; Result result;
            std::array<double, 5> elapsed;
            elapsed[0] = milliseconds([&] { prepared = memory.prepare(request, access); });
            require(bool(prepared.changes), Error::InvalidState);
            elapsed[1] = milliseconds([&] { checkpoint = memory.checkpoint_after(prepared.changes); });
            elapsed[2] = milliseconds([&] { bytes = encode_checkpoint(checkpoint); });
            elapsed[3] = milliseconds([&] {
                require(store.save(loaded.version + n - 1, checkpoint, checkpoint.requests.back()) == SaveOutcome::Committed,
                        Error::StorageUnavailable);
            });
            elapsed[4] = milliseconds([&] { result = memory.commit(prepared.changes); });
            require(result.applied() && result.sequence == n, Error::InvalidState);
            if (n > 1) for (unsigned stage = 0; stage < samples.size(); ++stage) samples[stage].push_back(elapsed[stage]);
        }
        require(encode_checkpoint(store.inspect().checkpoint) == bytes, Error::InvalidState);
        auto shutdown = milliseconds([&] { store.close(); });
        print_result(count, runs, bytes.size(), startup, shutdown, samples);
        return 0;
    } catch (const Violation& e) { std::cerr << name(e.code) << '\n'; }
    catch (const std::exception& e) { std::cerr << e.what() << '\n'; }
    return 1;
}
