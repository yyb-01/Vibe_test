#include "session.hpp"
#include "chamber.hpp"

namespace astra {
FireResult HostSession::dispatch_fire(Peer& peer, const FireIntent& intent, const FireObservation& observed) {
    validate_fire_intent(intent);
    if (auto settled = settle_fire(peer.account, intent)) return *settled;
    if (auto original = inventory_.recorded_fire(peer.account, intent.fireSeq)) {
        require(original->shot->intent == intent, Error::IdempotencyMismatch);
        auto result = inventory_.result_for(*original, peer.account);
        require(result.has_value(), Error::InvalidState);
        if (result->applied()) {
            fireCursors_.try_emplace(peer.account); weaponClocks_.try_emplace(original->moves[1].item);
            remember_fire({peer.account, original->moves[1].item, *original->shot, result->sequence}, now_(), false);
        }
        return {*result, result->applied() ? original->shot : std::nullopt};
    }
    require(!waitingFire_, Error::Busy);
    require(observed.pawn == peer.pawn && bool(observed.inventoryRoot) &&
        observed.authority.weaponOwner == peer.account, Error::NotAccessible);
    auto authority = observed.authority;
    authority.account = peer.account;
    authority.local = peer.connection == host_connection;
    authority.hasPrevious = false; // Session cursors and steady weapon clocks own previous acceptance.
    auto roots = inventory_.snapshot_roots({observed.inventoryRoot});
    const auto& world = *roots.roots.at(observed.inventoryRoot);
    auto chamber = chamber_state(world, observed.weapon);
    require(bool(chamber.round) && chamber.round == observed.ammo, Error::NotAccessible);
    authority.chambered = true; // Derived from the ledger, not the observation cache.
    auto effective = validate_fire_candidate(intent, authority);
    check_fire_clock(peer.account, observed.weapon, intent, authority, effective);
    auto entry = [&](Id item) {
        require(world.items.contains(item) && world.placements.contains(item), Error::NotAccessible);
        const auto& state = world.items.at(item);
        auto source = world.placements.at(item).container;
        require(ancestry(world, source).back() == observed.inventoryRoot, Error::NotAccessible);
        auto revision = world.containers.at(source).state.revision;
        return MoveEntry{item, source, source, state.revision, revision, revision, 1};
    };
    Request request{{fire_request_namespace, intent.fireSeq}, inventory_.next_action_sequence(peer.account),
        Operation::Fire, {entry(observed.ammo), entry(observed.weapon)}, roots.sequence, info_.epoch};
    request.shot = ShotData{intent, observed.launch, observed.massMg, effective,
        observed.ammoDef, observed.visualSeed, observed.durabilityCost};
    Access access{peer.account, info_.epoch, info_.epoch, {observed.inventoryRoot}};
    auto approved = approve_fire(request, authority, std::move(access));
    require(weaponClocks_.contains(observed.weapon) || weaponClocks_.size() < 65536, Error::LimitExceeded);
    fireCursors_.try_emplace(peer.account); weaponClocks_.try_emplace(observed.weapon);
    waitingFire_.emplace(WaitingFire{peer.account, request, now_()}); // Allocate before durable submission.
    auto result = inventory_.apply(request, approved);
    if (result.applied())
        remember_fire({peer.account, observed.weapon, *request.shot, result.sequence}, waitingFire_->admitted, true);
    if (result.code != Error::Pending) waitingFire_.reset();
    return {result, result.applied() ? request.shot : std::nullopt};
}
FireResult HostSession::receive_fire(std::uint64_t connection, const std::vector<std::uint8_t>& bytes,
    const FireObservation& observed, std::size_t budget) {
    owner();
    try {
        auto& p = admit_command(connection);
        return dispatch_fire(p, decode_fire_packet(bytes, info_.epoch, budget).intent, observed);
    } catch (const Violation& error) { return {failure(error.code), {}}; }
}
FireResult HostSession::fire_local(const FireIntent& intent, const FireObservation& observed) {
    owner();
    try { return dispatch_fire(admit_command(host_connection), intent, observed); }
    catch (const Violation& error) { return {failure(error.code), {}}; }
}
}
