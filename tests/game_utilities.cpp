#include "game_fixture.hpp"
void game_utilities_and_mounts(){
    GameFixture f(2);auto build=f.command(GameOperation::Build);build.definition=10;build.position={2,0,.1};CHECK(f.send(build).applied());
    auto foundation=f.game.state().structures.begin()->first;
    build=f.command(GameOperation::Build);build.definition=17;build.position={2,0,.55};build.targets[0]=foundation;CHECK(f.send(build).applied());
    auto state=f.game.state();Id storage;for(auto& [id,s]:state.crafting.stations)if(state.structures.contains(id))storage=id;
    auto container=state.crafting.stations.at(storage).output;
    auto put=f.command(GameOperation::InventoryMove);put.targets={Id{5,10014},container,{}};put.quantity=93;CHECK(f.send(put).applied());
    CHECK(f.storage.inventory->snapshot()->placements.at(put.targets[0]).container==container);
    auto lock=f.command(GameOperation::Lock);lock.targets[0]=storage;lock.enabled=true;CHECK(f.send(lock).applied());
    GamePeer guest{{7,2},{5,1001},false,true};put=f.command(GameOperation::InventoryMove);put.targets={Id{5,10014},Id{5,2001},{}};put.quantity=93;put.position={12,12,0};
    CHECK(f.send(put,guest).code==Error::NotAccessible);
    lock=f.command(GameOperation::Lock);lock.targets[0]=storage;CHECK(f.send(lock).applied());
    put.id=f.command(GameOperation::InventoryMove).id;CHECK(f.send(put,guest).applied());
    CHECK(f.storage.inventory->snapshot()->placements.at(put.targets[0]).container==Id(5,2001));
    put=f.command(GameOperation::InventoryMove);put.targets={Id{5,10014},container,{}};put.quantity=93;CHECK(f.send(put,guest).applied());
    put=f.command(GameOperation::InventoryMove);put.targets={Id{5,10014},Id{5,2000},{}};put.quantity=93;put.position={12,12,0};CHECK(f.send(put).applied());
    build=f.command(GameOperation::Build);build.definition=18;build.position={2,1.05,.55};build.targets[0]=foundation;CHECK(f.send(build).applied());
    Id bench;for(auto& [id,s]:f.game.state().structures)if(s.definition==18)bench=id;
    auto craft=f.command(GameOperation::Craft);craft.targets[0]=bench;craft.definition=1;CHECK(f.send(craft).applied());f.ticks(60);
    CHECK(f.game.state().crafting.jobs.begin()->second.phase==JobPhase::OutputReady);
    auto destroy=f.command(GameOperation::Destroy);destroy.targets[0]=bench;CHECK(f.send(destroy).applied());f.ticks(1);
    CHECK(f.game.state().crafting.stations.at(bench).wreck);
    auto move=f.command(GameOperation::Move);move.position={4,0,0};move.sequence=1;CHECK(f.send(move).applied());
    auto detach=f.command(GameOperation::DetachVehicle);detach.targets={Id{5,6000},Id{5,6010},{}};detach.revision=f.game.state().vehicles.at(detach.targets[0]).assemblyRevision;CHECK(f.send(detach).applied());
    CHECK(!f.game.state().vehicles.at(detach.targets[0]).torquePath);
    auto attach=f.command(GameOperation::AttachVehicle);attach.targets=detach.targets;attach.definition=1;attach.revision=f.game.state().vehicles.at(attach.targets[0]).assemblyRevision;CHECK(f.send(attach).applied());
    CHECK(f.game.state().vehicles.at(attach.targets[0]).torquePath&&f.storage.inventory->snapshot()->placements.at(attach.targets[1]).kind==PlaceKind::Socket);
    auto fuel=f.command(GameOperation::Refuel);fuel.targets[0]={5,6000};auto prior=f.game.state().vehicles.at(fuel.targets[0]).fuelUl;CHECK(f.send(fuel).applied());
    CHECK(f.game.state().vehicles.at(fuel.targets[0]).fuelUl==prior+1000000);
}
