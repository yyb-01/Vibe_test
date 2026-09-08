#pragma once
#include "sqlite_scenario.hpp"

class LostReply : public DurableStore {
public:
    SQLiteStore real;
    bool before{}, unreadable{};
    explicit LostReply(const std::filesystem::path& path) : real(path) {}
    StoredWorld acquire(const Checkpoint& c) override { return real.acquire(c); }
    SaveOutcome save(std::uint64_t v, const Checkpoint& c, const SavedRequest& r) override {
        if (before) return SaveOutcome::Unknown;
        auto result = real.save(v, c, r);
        return result == SaveOutcome::Committed ? SaveOutcome::Unknown : result;
    }
    StoredWorld inspect() override {
        require(!unreadable, Error::StorageUnavailable);
        return real.inspect();
    }
    void close() override { real.close(); }
};
