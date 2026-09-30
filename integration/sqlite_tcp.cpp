#ifdef _WIN32
#include "../network_tests/fire_exchange.hpp"
#include "sqlite_combat_fixture.hpp"
#include "fire_receipt.hpp"

void sqlite_tcp(const std::filesystem::path& path) {
  WSADATA data{}; CHECK(WSAStartup(MAKEWORD(2, 2), &data) == 0);
  struct Cleanup { ~Cleanup() { WSACleanup(); } } cleanup;
  auto initial = fire_clock_seed(); auto input = shot_request(seed()).shot->intent;
  AuthenticatedPeer peer{{77, 2}, {14, 2}};
  std::optional<ShotData> original;
  {
    auto driver = std::make_unique<LostReply>(path); auto* fault = driver.get();
    DurableInventory inventory(std::move(driver), initial);
    HostSession session(inventory, session_info(), {14, 1}, fixed_time);
    auto host = std::make_unique<HostTransport>(session, peer, session.info());
    auto socket = std::make_unique<Loopback>(); auto info = session.info();
    ClientTransport client({{info.world, peer.account, info.catalogHash}, info.epoch, 0, 1}, fire_catalog());
    auto token = client.open_authenticated(info.epoch);
    auto observation = combat_observation(peer.account, peer.pawn);
    auto exchange = [&] { return exchange_fire(*host, client, *socket, token, observation); };
    decode_resume(exchange(), info.epoch); client.submit_fire(token, input);
    auto pending = decode_fire_receipt(exchange(), info.epoch).receipt;
    CHECK(pending.status == TransactionStatus::Pending && !pending.accepted && session.active_shots().empty());
    CHECK(fault->real.inspect().checkpoint.world.items.at(id(100)).quantity == 0);
    client.disconnect(token); host->disconnect(); socket->close();
    astra::ballistics::Atmosphere vacuum; vacuum.gravity = {};
    session.advance_combat(101 * 65536, vacuum, {});
    CHECK(session.active_shots().size() == 1 && session.active_shots()[0].projectile.ageSubsteps == 4);
    host = std::make_unique<HostTransport>(session, peer, session.info());
    socket = std::make_unique<Loopback>(); observation = {};
    token = client.open_authenticated(info.epoch); decode_resume(exchange(), info.epoch);
    client.retry_fire(token, input.fireSeq);
    auto accepted = decode_fire_receipt(exchange(), info.epoch).receipt;
    CHECK(accepted.accepted && accepted.accepted->shotId == 1);
    original = inventory.recorded_fire(peer.account, input.fireSeq)->shot;
    CHECK(original);
    client.retry_fire(token, input.fireSeq);
    CHECK(decode_fire_receipt(exchange(), info.epoch).receipt == accepted && session.active_shots().size() == 1);
    CHECK(inventory.snapshot()->items.at(id(104)).durability == 65530);
    host->disconnect(); socket->close(); CHECK(session.close().applied());
  }
  DurableInventory inventory(std::make_unique<SQLiteStore>(path), initial);
  HostSession host(inventory, session_info(), {14, 1}, fixed_time);
  auto connection = host.admit_authenticated(peer, host.info());
  PacketHeader header; header.messageType = MessageType::FireIntent; header.worldEpoch = host.info().epoch;
  auto replay = host.receive_fire(connection, encode_fire_packet(header, input), {});
  CHECK(replay.result.applied() && replay.result.sequence == 1 && replay.accepted == original);
  CHECK(inventory.snapshot()->items.at(id(100)).quantity == 0 && host.active_shots().empty());
  CHECK(host.close().applied());
}
#endif
