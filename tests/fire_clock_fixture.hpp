#pragma once
#include "session_fixture.hpp"
#include "fire_scenario.hpp"

inline TransactionBudget::Clock::time_point fire_test_time;
inline auto fire_clock_now() { return fire_test_time; }
inline Checkpoint fire_clock_seed() {
    auto w = fire_seed(); auto& p = w.placements.at(id(104)); p.container = id(10); p.x = p.y = 4;
    add_item(w, 105, 3, 1, 10, 4, 5);
    add_chamber(w, 51, id(105)); add_item(w, 107, 1, 1, 51); w.placements.at(id(107)).socketId = 1;
    --w.items.at(id(106)).quantity;
    return Inventory(fire_catalog(), w, 1, 1).checkpoint();
}
struct FireClockScenario {
    AsyncScenario s;
    HostSession host;
    AuthenticatedPeer remote{{77, 2}, {14, 2}};
    std::uint64_t connection{};
    FireIntent intent = shot_request(seed()).shot->intent;
    FireObservation observation;
    explicit FireClockScenario(Checkpoint initial = fire_clock_seed())
        : s(std::move(initial)), host(*s.inventory, session_info(), {14, 1}, fire_clock_now) {
        connection = host.admit_authenticated(remote, host.info());
        observation.pawn = remote.pawn; observation.inventoryRoot = id(10);
        observation.weapon = id(104); observation.ammo = id(100);
        observation.authority = shot_authority(); observation.authority.weaponOwner = remote.account;
        auto shot = *shot_request(seed()).shot;
        observation.launch = shot.launch; observation.massMg = shot.massMg; observation.ammoDef = shot.ammoDef;
        observation.visualSeed = shot.visualSeed; observation.durabilityCost = shot.durabilityCost;
    }
    FireResult send(const FireIntent& input, const FireObservation& state) {
        PacketHeader h; h.messageType = MessageType::FireIntent; h.worldEpoch = host.info().epoch;
        return host.receive_fire(connection, encode_fire_packet(h, input), state);
    }
    FireResult send() { return send(intent, observation); }
    void next() {
        ++intent.inputSeq; ++intent.fireSeq; ++intent.clientFireTick; observation.authority.nowQ16 += 65536;
    }
    void written() { eventually([&] { s.store->ready(); return !s.store->status().busy; }); }
    void load() {
        auto world = s.inventory->snapshot(); auto loaded = chamber_state(*world, observation.weapon);
        if (loaded.round) { observation.ammo = loaded.round; return; }
        auto seq = s.inventory->next_action_sequence(remote.account);
        auto request = chamber_request(*world, observation.weapon, id(106), {88, seq + 100}, seq, 99);
        Access access{remote.account, s.inventory->epoch(), 99, {id(10)}};
        auto result = s.inventory->apply(request, access);
        if (result.code == Error::Pending) { written(); result = s.inventory->apply(request, access); }
        CHECK(result.applied()); observation.ammo = result.created ? result.created : id(106);
    }
};
