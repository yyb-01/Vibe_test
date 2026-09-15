#include "session.hpp"
#include <chrono>
#include <thread>

namespace {
// Console-only bounded wait. An engine host must poll once per tick instead.
template<class F> Result settle(F poll) {
    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    for (;;) {
        auto result = poll();
        if (result.code != Error::Pending || std::chrono::steady_clock::now() >= deadline) return result;
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}
}
std::shared_ptr<const World> Session::snapshot() {
    if (client) return client->snapshot();
    return durable ? durable->snapshot() : memory->snapshot();
}
Request Session::request(Operation op, std::vector<MoveEntry> moves) {
    require(!pending && !closing, Error::Busy);
    auto next = client ? client->next_action_sequence() : durable ? durable->next_action_sequence(access.account) : memory->next_action_sequence(access.account);
    require(!client || nextRequest < revision_limit, Error::LimitExceeded);
    auto requestId = client ? nextRequest++ : next;
    return {{access.epoch, requestId}, next, op, std::move(moves), 0, client ? client->lease() : access.interactionLease};
}
Result Session::apply(const Request& request, bool wait) {
    require(!closing, Error::Busy);
    auto result = client ? client->apply(request) : durable ? durable->apply(request, access) : memory->apply(request, access);
    if (result.code == Error::Pending) { pending = true; return wait ? resolve() : result; }
    if (result.code != Error::Busy && result.code != Error::IdempotencyMismatch)
        pending = result.code == Error::EpochMismatch || result.code == Error::InvalidState;
    return result;
}
Result Session::resolve() {
    require(pending && bool(durable), Error::InvalidRequest);
    auto result = settle([&] { return client ? client->retry() : durable->resolve(); });
    // Fenced/inconsistent outcomes still require recovery, never admit new work.
    pending = result.code == Error::Pending || result.code == Error::EpochMismatch || result.code == Error::InvalidState;
    return result;
}
Result Session::close() {
    closing = true;
    if (client && pending && !client->connected()) client->reconnect();
    if (client && pending) { auto result = resolve(); if (pending) return result; }
    if (client) return settle([&] { return client->close(); });
    return durable ? settle([&] { return durable->close(); }) : Result{};
}
