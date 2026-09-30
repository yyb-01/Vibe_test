#include "fire_exchange.hpp"
#include "../tests/session_fixture.hpp"
#include "../tests/fire_scenario.hpp"
#include "transport.hpp"
#include "fire_receipt.hpp"
#include "client_transport.hpp"

void tcp_fire() {
    auto world = fire_seed(); auto& weapon = world.placements.at(id(104));
    weapon.container = id(10); weapon.x = weapon.y = 4;
    AsyncScenario s(Inventory(fire_catalog(), world, 1, 1).checkpoint());
    HostSession session(*s.inventory, session_info(), {14, 1}, fixed_time);
    AuthenticatedPeer peer{{77, 2}, {14, 2}};
    auto host = std::make_unique<HostTransport>(session, peer, session.info());
    auto socket = std::make_unique<Loopback>();
    auto info = session.info();
    ClientTransport client({{info.world, peer.account, info.catalogHash}, info.epoch, 0, 1}, fire_catalog());
    auto token = client.open_authenticated(info.epoch);
    FireObservation observation;
    observation.pawn = peer.pawn; observation.inventoryRoot = id(10);
    observation.weapon = id(104); observation.ammo = id(100);
    observation.authority = shot_authority(); observation.authority.weaponOwner = peer.account;
    auto shot = *shot_request(world).shot;
    observation.launch = shot.launch; observation.massMg = shot.massMg;
    observation.ammoDef = shot.ammoDef; observation.visualSeed = shot.visualSeed;
    observation.durabilityCost = shot.durabilityCost;
    auto exchange = [&] { return exchange_fire(*host, client, *socket, token, observation); };
    decode_resume(exchange(), session.info().epoch);
    PacketHeader h; h.worldEpoch = session.info().epoch; h.messageType = MessageType::FireIntent;
    s.probe->hold = true;
    client.submit_fire(token, shot.intent);
    auto pending = decode_fire_receipt(exchange(), h.worldEpoch).receipt;
    CHECK(pending.status == TransactionStatus::Pending && !pending.accepted);
    CHECK(client.state().fire_status(shot.intent.fireSeq) == pending);
    auto old = token; client.disconnect(token);
    host->disconnect(); socket->close(); s.probe->release();
    eventually([&] { s.store->ready(); return !s.store->status().busy; });
    host = std::make_unique<HostTransport>(session, peer, session.info());
    socket = std::make_unique<Loopback>(); observation = {};
    token = client.open_authenticated(h.worldEpoch);
    decode_resume(exchange(), h.worldEpoch);
    rejects([&] { client.retry_fire(old, shot.intent.fireSeq); }, Error::InvalidState);
    client.retry_fire(token, shot.intent.fireSeq);
    auto accepted = decode_fire_receipt(exchange(), h.worldEpoch).receipt;
    CHECK(accepted.accepted && accepted.accepted->shotId == 1);
    CHECK(client.state().fire_status(shot.intent.fireSeq) == accepted);
    client.retry_fire(token, shot.intent.fireSeq);
    CHECK(decode_fire_receipt(exchange(), h.worldEpoch).receipt == accepted);
    CHECK(s.probe->saves == 1 && s.inventory->snapshot()->items.at(id(100)).quantity == 0);
    client.forget_fire(shot.intent.fireSeq);
}
