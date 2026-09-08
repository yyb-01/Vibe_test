#include "sqlite.hpp"
#include "sqlite_db.hpp"

namespace astra {
SaveOutcome SQLiteStore::save(std::uint64_t version, const Checkpoint& target, const SavedRequest& record) {
    require(lock_ && epoch_ && target.epoch == epoch_ && version < revision_limit && !target.requests.empty(),
            Error::InvalidState);
    const auto& last = target.requests.back();
    require(last.account == record.account && last.requestId == record.requestId &&
            last.actionSeq == record.actionSeq && last.payload == record.payload &&
            last.result.code == record.result.code && last.result.sequence == record.result.sequence &&
            last.result.created == record.result.created, Error::InvalidState);
    auto bytes = encode_checkpoint(target);
    bool committing = false;
    try {
        sq::Connection db(path_); sq::configure(db);
        db.exec("BEGIN IMMEDIATE");
        auto current = sq::load(db);
        if (current.checkpoint.epoch != epoch_) return SaveOutcome::Fenced;
        if (current.version != version) {
            if (current.version == version + 1 && encode_checkpoint(current.checkpoint) == bytes)
                return SaveOutcome::Committed;
            return SaveOutcome::Fenced;
        }
        require(current.checkpoint.origin == target.origin && current.checkpoint.catalog == target.catalog &&
                target.requests.size() == current.checkpoint.requests.size() + 1, Error::InvalidState);
        sq::write(db, version + 1, bytes);
        committing = true;
        db.exec("COMMIT");
        return SaveOutcome::Committed;
    } catch (...) {
        // Connection close rolls back any unfinished write before inspect can reopen it.
        return committing ? SaveOutcome::Unknown : SaveOutcome::Aborted;
    }
}
}
