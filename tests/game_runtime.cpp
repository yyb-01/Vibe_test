#include "game_fixture.hpp"
void game_runtime_checks() {
    GameFixture f;auto water=f.command(GameOperation::Consume);water.targets[0]={5,10018};
    auto before=f.storage.inventory->snapshot();f.storage.probe->aborted=true;
    CHECK(f.send(water).code==Error::StorageUnavailable);CHECK(f.storage.inventory->snapshot()==before);
    f.storage.probe->aborted=false;auto consumed=f.send(water);CHECK(consumed.applied());
    CHECK(f.game.state().lives.at(f.player.actor).digestiveMl==500);CHECK(f.storage.inventory->snapshot()->items.at(water.targets[0]).quantity==2);
    CHECK(f.send(water).sequence==consumed.sequence);auto changed=water;changed.quantity=2;CHECK(f.send(changed).code==Error::IdempotencyMismatch);
    auto unauthorized=f.command(GameOperation::Tick);unauthorized.tick=1;CHECK(f.send(unauthorized).code==Error::NotAccessible);
    auto start=f.command(GameOperation::Craft);start.targets[0]={5,4000};start.definition=1;CHECK(f.send(start).applied());
    auto state=f.game.state();auto job=state.crafting.jobs.begin()->first;CHECK(state.crafting.jobs.at(job).phase==JobPhase::Running);
    f.ticks(60);state=f.game.state();CHECK(state.crafting.jobs.at(job).phase==JobPhase::OutputReady);
    auto collect=f.command(GameOperation::Collect);collect.targets[0]=job;CHECK(f.send(collect).applied());CHECK(f.game.state().crafting.jobs.at(job).phase==JobPhase::Collected);
    auto build=f.command(GameOperation::Build);build.definition=10;build.position={2,0,.1};CHECK(f.send(build).applied());
    auto fire=f.command(GameOperation::Fire);fire.targets[0]={5,10001};fire.sequence=1;fire.revision=1;CHECK(f.send(fire).applied());
    CHECK(f.game.state().weapons.at(fire.targets[0]).shotCounter==1&&f.game.state().shots.size()==1);
    CHECK(f.send(fire).applied()&&f.game.state().weapons.at(fire.targets[0]).shotCounter==1);
    f.ticks(10);bool hurt=false;for(auto& [id,z]:f.game.state().world.zombies){(void)id;hurt|=z.health<100;}CHECK(hurt);
    auto encoded=encode_game(f.game.state());CHECK(encode_game(decode_game(encoded))==encoded);
    auto denied=f.command(GameOperation::Consume);denied.targets[0]={5,10018};CHECK(f.send(denied,{{7,2},{5,1000},false,true}).code==Error::NotAccessible);
}
