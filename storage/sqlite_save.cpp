#include "sqlite.hpp"
#include "sqlite_db.hpp"
#include "../core/simulation_journal.hpp"

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
        if(!connection_){auto opened=std::make_unique<sq::Connection>(path_);sq::configure(*opened);connection_=std::move(opened);}
        auto& db=*connection_;
        db.exec("BEGIN IMMEDIATE");
        auto current = sq::load(db);
        if (current.checkpoint.epoch != epoch_){connection_.reset();return SaveOutcome::Fenced;}
        if (current.version != version) {
            auto outcome=current.version==version+1&&encode_checkpoint(current.checkpoint)==bytes?SaveOutcome::Committed:SaveOutcome::Fenced;
            connection_.reset();return outcome;
        }
        require(current.checkpoint.origin == target.origin && current.checkpoint.catalog == target.catalog &&
                request_count(target) == request_count(current.checkpoint)+1 &&
                target.retiredRequests>=current.checkpoint.retiredRequests &&
                target.retiredCommits>=current.checkpoint.retiredCommits, Error::InvalidState);
        sq::write(db, version + 1, bytes);
        committing = true;
        db.exec("COMMIT");
        return SaveOutcome::Committed;
    } catch (...) {
        // Keep successful connections open to avoid a last-connection WAL checkpoint every tick.
        // On any failure, closing still rolls back before inspect can determine the durable outcome.
        connection_.reset();
        return committing ? SaveOutcome::Unknown : SaveOutcome::Aborted;
    }
}
}
