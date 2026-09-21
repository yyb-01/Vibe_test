#include "client.hpp"
#include <thread>

namespace {
// Console-only wait for admission; engine integration must schedule once per tick.
template<class F> auto admitted(F operation) {
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    for (;;) {
        try { return operation(); }
        catch (const Violation& e) {
            if (e.code != Error::Busy || std::chrono::steady_clock::now() >= deadline) throw;
        }
        // Resume and snapshot admission need two tokens after reconnect.
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }
}
}
ResumeState ConsoleClient::read_resume() {
    auto state = admitted([&] { return host_.resume_state(transport_->connection()); });
    PacketHeader h; h.worldEpoch = host_.info().epoch; h.messageType = MessageType::SessionResume;
    return decode_resume(encode_resume(h, state), h.worldEpoch);
}
std::uint64_t ConsoleClient::next_action_sequence() {
    require(connected(), Error::NotAccessible);
    if (request_) {
        auto status = client_.state().status(request_->id).status;
        require(status == TransactionStatus::Committed || status == TransactionStatus::Rejected, Error::Busy);
    }
    auto state = read_resume();
    require(state.identity == resume_.identity, Error::NotAccessible);
    require(state.epoch == resume_.epoch, Error::EpochMismatch);
    require(state.sequence >= resume_.sequence && state.sequence >= client_.state().sequence() &&
            state.nextActionSequence >= resume_.nextActionSequence, Error::RevisionConflict);
    resume_ = state;
    return state.nextActionSequence;
}
void ConsoleClient::disconnect() {
    require(connected(), Error::NotAccessible);
    transport_.reset(); client_.disconnect(token_); lease_ = 0;
}
Result ConsoleClient::close() {
    if (transport_ && transport_->connection()) {
        auto ready = transport_->shutdown();
        if (!ready.applied()) return ready;
        exchange(false, true); lease_ = 0;
    }
    return host_.close();
}
void ConsoleClient::reconnect() {
    require(!connected(), Error::InvalidState);
    transport_.reset();
    admitted([&] {
        transport_ = std::make_unique<HostTransport>(host_,
            AuthenticatedPeer{{77, 1}, {14, 1}, IdentityKind::LocalLan}, host_.info());
    });
    token_ = client_.open_authenticated(host_.info().epoch);
    exchange();
}
std::shared_ptr<const World> ConsoleClient::snapshot() {
    require(connected(), Error::NotAccessible);
    admitted([&] {
        if (!connected()) reconnect();
        client_.request_snapshot(token_); exchange(true);
    });
    lease_ = client_.snapshot_lease(token_);
    return client_.state().view();
}
