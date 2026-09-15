#include "client_state.hpp"
#include <algorithm>

namespace astra {
ClientState::ClientState(const ResumeState& state, Catalog catalog)
    : ClientState(state.epoch, std::move(catalog)) {
    identity_ = state.identity; connected_ = false;
    reconnect(state);
}
void ClientState::disconnect() {
    connected_ = false; set_roots({});
    for (auto& [id, request] : requests_) { (void)request; timeout(id); }
}
void ClientState::reconnect(const ResumeState& state) {
    require(!connected_ && identity_ && bool(state.identity.account) && bool(state.identity.world), Error::InvalidState);
    require(state.identity == *identity_, Error::NotAccessible);
    require(state.epoch >= epoch_ && state.epoch <= revision_limit, Error::EpochMismatch);
    require(state.sequence >= published_ && state.sequence >= confirmed_ && state.sequence <= revision_limit &&
            state.nextActionSequence && state.nextActionSequence >= resumeSequence_ &&
            state.nextActionSequence <= revision_limit, Error::RevisionConflict);
    if (state.epoch != epoch_) latest_.reset();
    epoch_ = state.epoch;
    confirmed_ = std::max(confirmed_, state.sequence);
    resumeSequence_ = state.nextActionSequence;
    for (auto& [id, request] : requests_) { (void)id; request.receipt.durableWorldEpoch = epoch_; }
    connected_ = true;
}
}
