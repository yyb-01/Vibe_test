#pragma once
#include "durable.hpp"
#include <string>

namespace astra {
class PostgresStore final : public DurableStore {
public:
    PostgresStore(std::string connection, Id world);
    StoredWorld acquire(const Checkpoint&) override;
    SaveOutcome save(std::uint64_t version, const Checkpoint&, const SavedRequest&) override;
    StoredWorld inspect() override;
private:
    std::string connection_, world_;
    std::uint64_t epoch_{};
};
}
