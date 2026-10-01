#include "game_fixture.hpp"
void game_repair_and_dismantle(){
    GameFixture f;Id gun{5,10001};auto fire=f.command(GameOperation::Fire);fire.targets[0]=gun;fire.sequence=1;fire.revision=1;CHECK(f.send(fire).applied());
    auto worn=f.storage.inventory->snapshot()->items.at(gun).durability;CHECK(worn==65534);
    auto start=f.command(GameOperation::Craft);start.targets[0]={5,4000};start.definition=5;CHECK(f.send(start).applied());
    auto job=f.game.state().crafting.jobs.begin()->first;
    auto cancel=f.command(GameOperation::Cancel);cancel.targets[0]=job;CHECK(f.send(cancel).applied());
    auto collect=f.command(GameOperation::Collect);collect.targets[0]=job;CHECK(f.send(collect).applied());CHECK(f.storage.inventory->snapshot()->items.at(gun).durability==worn);
    start.id=f.command(GameOperation::Craft).id;CHECK(f.send(start).applied());f.ticks(60);
    for(auto& [id,j]:f.game.state().crafting.jobs)if(j.phase==JobPhase::OutputReady)job=id;
    CHECK(f.game.state().crafting.jobs.at(job).outputs==std::vector<Id>{gun});
    collect=f.command(GameOperation::Collect);collect.targets[0]=job;auto result=f.send(collect);CHECK(result.applied());CHECK(f.send(collect).sequence==result.sequence);
    CHECK(f.storage.inventory->snapshot()->items.at(gun).durability==65535&&f.storage.inventory->snapshot()->placements.at({5,10005}).kind==PlaceKind::Socket);
    start.id=f.command(GameOperation::Craft).id;CHECK(f.send(start).code==Error::InvalidQuantity);
    auto move=f.command(GameOperation::Move);move.position={3,0,0};move.sequence=1;CHECK(f.send(move).applied());
    auto detach=f.command(GameOperation::DetachVehicle);detach.targets={Id{5,6000},Id{5,6011},{}};detach.revision=1;CHECK(f.send(detach).applied());
    auto take=f.command(GameOperation::Loot);take.targets[0]=detach.targets[1];CHECK(f.send(take).applied());
    f.ticks(10);move=f.command(GameOperation::Move);move.position={2,0,0};move.sequence=2;CHECK(f.send(move).applied());
    start=f.command(GameOperation::Craft);start.targets[0]={5,4000};start.definition=6;CHECK(f.send(start).applied());f.ticks(60);
    CHECK(f.storage.inventory->snapshot()->items.at(take.targets[0]).flags&deleted);
}
