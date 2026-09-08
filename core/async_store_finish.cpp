#include "async_store.hpp"

namespace astra {
StoredWorld AsyncStore::inspect() {
    owner(); require(acquired_ && !closing_, Error::InvalidState);
    collect();
    if (running_) throw Violation{Error::Pending};
    if (!reply_ || reply_->failure) {
        uncertain_ = true;
        send({StoreCommand::Inspect, {}, 0, {}});
        throw Violation{Error::Pending};
    }
    auto result = loaded(); uncertain_ = false;
    return result;
}
void AsyncStore::close() {
    owner(); require(acquired_, Error::InvalidState);
    if (closed_) return;
    collect();
    require(!running_ || active_ == StoreCommand::Close, Error::Pending);
    closing_ = true;
    if (running_) throw Violation{Error::Pending};
    if (reply_ && active_ == StoreCommand::Close) {
        auto failure = reply_->failure;
        reply_.reset(); bytes_ = 0;
        if (failure) std::rethrow_exception(failure);
        closed_ = true; return;
    }
    send({StoreCommand::Close, {}, 0, {}});
    throw Violation{Error::Pending};
}
}
