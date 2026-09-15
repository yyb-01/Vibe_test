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
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
}
}
ResumeState ConsoleClient::read_resume() {
    auto state = admitted([&] { return host_.resume_state(connection_); });
    PacketHeader h; h.worldEpoch = host_.info().epoch; h.messageType = MessageType::SessionResume;
    return decode_resume(encode_resume(h, state), h.worldEpoch);
}
std::uint64_t ConsoleClient::next_action_sequence() {
    require(client_.connected(), Error::NotAccessible);
    if (request_) {
        auto status = client_.status(request_->id).status;
        require(status == TransactionStatus::Committed || status == TransactionStatus::Rejected, Error::Busy);
    }
    auto state = read_resume();
    require(state.identity == resume_.identity, Error::NotAccessible);
    require(state.epoch == resume_.epoch, Error::EpochMismatch);
    require(state.sequence >= resume_.sequence && state.sequence >= client_.sequence() &&
            state.nextActionSequence >= resume_.nextActionSequence, Error::RevisionConflict);
    resume_ = state;
    return state.nextActionSequence;
}
void ConsoleClient::disconnect() {
    require(client_.connected(), Error::NotAccessible);
    host_.disconnect(connection_); connection_ = 0;
    client_.disconnect(); lease_ = 0;
}
Result ConsoleClient::close() {
    auto ready = host_.prepare_close();
    if (!ready.applied()) return ready;
    // In-process shutdown notification: clear client state before closing the DB.
    client_.disconnect(); lease_ = 0;
    return host_.close();
}
void ConsoleClient::reconnect() {
    require(!client_.connected(), Error::InvalidState);
    if (!connection_) connection_ = host_.admit_authenticated(
        {{77, 1}, {14, 1}, IdentityKind::LocalLan}, host_.info());
    auto state = read_resume();
    client_.reconnect(state); resume_ = state;
}
std::shared_ptr<const World> ConsoleClient::snapshot() {
    require(client_.connected(), Error::NotAccessible);
    auto state = observation();
    lease_ = host_.grant_lease(connection_, state);
    client_.set_roots({id(10), id(20), id(30)});
    auto descriptor = admitted([&] { return host_.start_snapshot(connection_, lease_, state); });
    client_.begin_snapshot(descriptor);
    for (std::size_t page = 0; page < snapshot_pages(descriptor); ++page) {
        auto bytes = admitted([&] { return host_.snapshot_page(connection_, descriptor.id, page, state); });
        client_.receive_page(bytes);
    }
    require(!client_.needs_refresh() && bool(client_.view()), Error::InvalidState);
    return client_.view();
}
