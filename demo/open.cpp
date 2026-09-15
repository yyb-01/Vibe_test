#include "session.hpp"
#ifdef ASTRA_DEMO_SQLITE
#include "async_store.hpp"
#include "sqlite.hpp"
#include <thread>
#endif

Session::Session(const std::filesystem::path& save, bool clientMode) {
    require(!clientMode || !save.empty(), Error::InvalidRequest);
    if (save.empty()) {
        memory = std::make_unique<Inventory>(catalog(), seed(), 1, 1);
        return;
    }
#ifdef ASTRA_DEMO_SQLITE
    if (save.has_parent_path()) std::filesystem::create_directories(save.parent_path());
    auto initial = Inventory(catalog(), seed(), 1, 1).checkpoint();
    auto driver = std::make_unique<AsyncStore>(
        [save] { return std::make_unique<SQLiteStore>(save); }, initial);
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(10);
    while (!driver->ready()) {
        require(std::chrono::steady_clock::now() < deadline, Error::StorageUnavailable);
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    durable = std::make_unique<DurableInventory>(std::move(driver), initial);
    access.epoch = durable->epoch();
    if (clientMode) client = std::make_unique<ConsoleClient>(*durable);
#else
    throw std::runtime_error("SQLite support is unavailable. Run scripts/play.ps1 -SavePath PATH.");
#endif
}
