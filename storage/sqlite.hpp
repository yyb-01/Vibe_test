#pragma once
#include "durable.hpp"
#include "world_lock.hpp"

namespace astra {
// One world per file. Call through DurableInventory, which serializes operations.
class SQLiteStore final : public DurableStore {
public:
    explicit SQLiteStore(const std::filesystem::path& path);
    StoredWorld acquire(const Checkpoint&) override;
    SaveOutcome save(std::uint64_t, const Checkpoint&, const SavedRequest&) override;
    StoredWorld inspect() override;
    void close() override;
private:
    std::filesystem::path path_;
    std::unique_ptr<WorldLock> lock_;
    std::uint64_t epoch_{};
};
}
