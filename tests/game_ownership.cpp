#include "game_fixture.hpp"
#include "simulation_journal.hpp"
void game_journal_ownership() {
    GameFixture f;Inventory journal(survival_seed(f.defs));
    for(unsigned n=1;n<=3;++n) {
        GameCommand c;c.id={9,n};c.operation=GameOperation::Tick;c.tick=n;
        Request r;r.id=c.id;r.actionSeq=n;r.operation=Operation::System;r.systemRoots={game_root};r.command=encode_command(c);r.interactionLease=1;
        r.mutation=[](World& w,Id,std::uint64_t){auto s=decode_game(w.containers.at(game_root).gameplay);++s.tick;++s.revision;w.containers.at(game_root).gameplay=encode_game(s);};
        Access a{simulation_account,1,1,{game_root}};a.approvedSystem=encode(r);CHECK(journal.apply(r,a).applied());
    }
    auto saved=journal.checkpoint();CHECK(saved.retiredRequests==2&&saved.retiredCommits==2&&saved.requests.size()==1);
    CHECK(request_count(saved)==3);auto restored=decode_checkpoint(encode_checkpoint(saved));Inventory memory(restored);
    CHECK(memory.next_action_sequence(simulation_account)==4);
    f.ticks(3);
    auto drop=f.command(GameOperation::Drop);drop.targets[0]={5,10001};CHECK(f.send(drop).applied());
    auto s=f.game.state();CHECK(!s.controls.at(f.player.actor).weapon&&!s.weapons.at(drop.targets[0]).owner);
    auto fire=f.command(GameOperation::Fire);fire.targets[0]=drop.targets[0];fire.sequence=1;fire.revision=s.weapons.at(drop.targets[0]).assemblyRevision;
    CHECK(f.send(fire).code==Error::NotAccessible);
    auto take=f.command(GameOperation::Loot);take.targets[0]=drop.targets[0];CHECK(f.send(take).applied());
    auto equip=f.command(GameOperation::Equip);equip.targets[0]=drop.targets[0];equip.enabled=true;CHECK(f.send(equip).applied());
    CHECK(f.game.state().weapons.at(drop.targets[0]).owner==f.player.account);
    auto split=f.command(GameOperation::InventorySplit);split.targets={Id{5,10014},Id{5,2000},{}};split.quantity=10;split.position={12,12,0};
    auto result=f.send(split);CHECK(result.applied());CHECK(f.storage.inventory->snapshot()->items.at(split.targets[0]).quantity==90);
    CHECK(f.send(split).sequence==result.sequence);
    auto start=f.command(GameOperation::Craft);start.targets[0]={5,4000};start.definition=1;CHECK(f.send(start).applied());f.ticks(60);
    start.id=f.command(GameOperation::Craft).id;start.definition=2;start.targets[0]={5,4001};CHECK(f.send(start).applied());f.ticks(120);
    Id prior;for(auto& [id,j]:f.game.state().crafting.jobs)if(j.recipe==2)prior=id;
    start.id=f.command(GameOperation::Craft).id;CHECK(f.send(start).applied());
    auto cancel=f.command(GameOperation::Cancel);cancel.targets[0]=prior;CHECK(f.send(cancel).applied());
    CHECK(f.game.state().crafting.toolLeases.contains({5,10017}));
    Wheel wheel;WheelDef d;WheelContact contact;contact.hit=true;contact.distance=.55;
    auto force=wheel_force(wheel,d,contact,500,3000,1.0/60);CHECK(std::abs(force.force.x)<1e-9&&wheel.omega==0);
}
