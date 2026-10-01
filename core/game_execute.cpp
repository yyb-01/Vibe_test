#include "game_execution.hpp"
namespace astra {
bool inventory_action(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t);
void synchronize_ownership(const World&,GameState&);
bool belongs_to(const World& w,Id item,Id root) {
    return w.items.contains(item)&&!(w.items.at(item).flags&deleted)&&w.placements.contains(item)&&ancestry(w,w.placements.at(item).container).back()==root;
}
Id actor_inventory(const GameState& s,const GamePeer& p) {
    require(s.lives.contains(p.actor)&&s.lives.at(p.actor).account==p.account,Error::NotAccessible);return s.lives.at(p.actor).inventory;
}
void execute_game(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds& ids,std::uint64_t event) {
    if(c.operation==GameOperation::Tick) {
        require(p.host&&p.account==simulation_account&&c.tick==s.tick+1,Error::NotAccessible);
        simulation_tick(d,w,s,ids,event);
    } else {
        actor_inventory(s,p);auto& life=s.lives.at(p.actor);
        require(life.epoch==c.lifeEpoch,Error::RevisionConflict);
        require(c.operation==GameOperation::Presence||(s.controls.at(p.actor).connected&&(c.operation==GameOperation::Respawn||life.status==LifeStatus::Conscious)),Error::NotAccessible);
        check_reload_access(w,s,c);
        if(!player_action(d,w,s,c,p,ids,event)&&!economy_action(d,w,s,c,p,ids,event)&&
            !building_action(d,w,s,c,p,ids,event)&&!ground_action(d,w,s,c,p,ids,event)&&
            !vehicle_action(d,w,s,c,p,ids,event)&&!combat_action(d,w,s,c,p,ids,event)&&
            !inventory_action(d,w,s,c,p,ids,event))throw Violation{Error::InvalidRequest};
    }
    finish_deaths(d,w,s,ids,event);
    synchronize_ownership(w,s);
    record_history(w,s);validate_game_world(d,w,s);
}
std::uint16_t game_allocation_budget(const GameDefinitions& d,const GameState& s,const GameCommand& c) {
    unsigned need=0;
    if(c.operation==GameOperation::Craft)need=34;
    if(c.operation==GameOperation::InventorySplit)need=1;
    if(c.operation==GameOperation::Build)need=4;
    if(c.operation==GameOperation::Loot)need=1;
    if(c.operation==GameOperation::Destroy||c.operation==GameOperation::DetachVehicle)need=2;
    if(c.operation==GameOperation::Reload||c.operation==GameOperation::Fire)need=1;
    if(c.operation==GameOperation::Tick) {
        need=unsigned(s.weapons.size());
        for(auto& [id,station]:s.crafting.stations){(void)id;if(station.destroyed&&!station.wreck)++need;}
        for(auto& [id,asset]:s.groundAssets){(void)id;if(!asset.item&&asset.spawnDef&&s.tick+1>=asset.nextSpawnTick)++need;}
        for(auto& [id,j]:s.crafting.jobs) {
            (void)id;if(j.phase!=JobPhase::Running&&j.phase!=JobPhase::Paused)continue;
            const auto& r=d.recipes.at(j.recipe);auto progress=std::min(r.durationUs,j.progressUs+16667);
            for(auto o:r.outputs) {auto stage=o.stage==255?r.stages.size()-1:o.stage;
                if(stage>=j.stage&&(!r.durationUs||progress*1000>=r.durationUs*r.stages.at(stage))) {
                    auto n=std::uint64_t(o.quantity)*j.batch;need+=unsigned((n+d.items.at(o.def).maxStack-1)/d.items.at(o.def).maxStack);
                }
            }
        }
    }
    for(auto& [id,l]:s.lives){(void)id;if(!l.corpse)need+=2;}
    require(need<=4096,Error::LimitExceeded);return std::uint16_t(need);
}
}
