#include "async_store.hpp"

namespace astra {
SaveOutcome AsyncStore::save_delta(std::uint64_t version, const CheckpointDelta& delta) {
    owner(); require(acquired_ && !closing_ && !running_ && !uncertain_ && !deltaPending_, Error::Busy);
    // No DB command exists yet: serialization/admission failure is a definite abort.
    try {
        auto bytes = encode_delta(delta);
        if (bytes.capacity() > db_message_limit) return SaveOutcome::Limited;
        send({StoreCommand::SaveDelta, std::move(bytes), version, {}});
    } catch (const Violation& e) {
        return e.code == Error::LimitExceeded ? SaveOutcome::Limited : SaveOutcome::Aborted;
    } catch (...) { return SaveOutcome::Aborted; }
    deltaPending_ = true;
    return SaveOutcome::Unknown;
}
SaveOutcome AsyncStore::resolve_delta() {
    owner(); require(acquired_ && deltaPending_ && !closing_, Error::InvalidState);
    collect();
    if (running_) return SaveOutcome::Unknown;
    if (!reply_ || reply_->failure) {
        uncertain_ = true;
        send({StoreCommand::ResolveDelta, {}, 0, {}});
        return SaveOutcome::Unknown;
    }
    auto result = reply_->outcome;
    if (result != SaveOutcome::Unknown) {
        uncertain_ = deltaPending_ = false; reply_.reset(); bytes_ = 0;
    }
    return result;
}
}
