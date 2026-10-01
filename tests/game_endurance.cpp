#include "game_fixture.hpp"
#include "game_execution.hpp"
void game_injury_endurance(){
    Life life;life.entity={1,1};life.account={2,1};life.inventory={3,1};
    for(unsigned i=1;i<=128;++i)wound_progress(life,i,Region::LeftArm,1,false,0);
    CHECK(life.wounds.size()==64);double bleed=0;
    for(auto& w:life.wounds)bleed+=(w.arterialMlS+w.venousMlS)*w.treatment;
    CHECK(std::abs(bleed-.768)<1e-9&&std::abs(life.health[4]-87.2)<1e-9);
    wound_progress(life,2,Region::LeftArm,2,false,1);CHECK(std::abs(life.health[4]-87.1)<1e-9);validate_life(life);
    ArmorMap single,split;damage_armor_progress(single,.35,.65,200,0,.12);
    for(unsigned i=1;i<=200;++i)damage_armor_progress(split,.35,.65,i,i-1,.12);
    CHECK(single.integrity==split.integrity);
    Vehicle vehicle;vehicle.position={1999.9,-1999.9,.4};vehicle.velocity={30,-30,0};
    integrate_vehicle(vehicle,{},MassProperties{1000,{},diagonal(100,100,100)});
    CHECK(vehicle.position.x==1999.99&&vehicle.position.y==-1999.99&&vehicle.velocity.x==0&&vehicle.velocity.y==0);
    GameFixture f;f.ticks(2000);auto s=f.game.state();CHECK(s.tick==2000&&s.lives.at(f.player.actor).status==LifeStatus::Dead&&s.lives.at(f.player.actor).corpse);
    auto respawn=f.command(GameOperation::Respawn);CHECK(f.send(respawn).applied());f.ticks(20);
    CHECK(f.game.state().lives.at(f.player.actor).epoch==2);
}
