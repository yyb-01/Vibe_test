#include "game_execution.hpp"
namespace astra {
void tick_weapons(const GameDefinitions&,World&,GameState&,GameIds&,std::uint64_t);
void tick_ground(const GameDefinitions&,World&,GameState&,GameIds&,std::uint64_t);
void finish_stations(const GameDefinitions&,World&,GameState&,GameIds&,std::uint64_t);
unsigned craft_output_budget(const GameDefinitions&,const CraftJob&,std::uint64_t);
void simulation_tick(const GameDefinitions& d,World& w,GameState& s,GameIds& ids,std::uint64_t event) {
    ++s.tick;auto dt=s.tick%3==1?16666u:16667u;
    finish_stations(d,w,s,ids,event);
    tick_vehicles(d,s);
    for(auto& [id,l]:s.lives) {
        if(!active_player(s.controls.at(id),s.tick)){l.tick=s.tick;continue;}
        Environment env;env.sheltered=shelter(l.position,s.structures,d.structures);
        env.resting=!s.controls.at(id).vehicle&&s.tick-s.controls.at(id).moveTick>30;
        env.movementW=env.resting?0:200;advance_life(l,env,s.tick);
    }
    record_history(w,s);tick_weapons(d,w,s,ids,event);run_ballistics(d,w,s,event);
    for(auto& [id,node]:s.power.nodes){(void)id;node.demandW=0;}
    for(auto& [id,j]:s.crafting.jobs)if(j.phase==JobPhase::Running||j.phase==JobPhase::Paused) {
        (void)id;auto& r=d.recipes.at(j.recipe);auto power=s.crafting.stations.at(j.station).powerNode;
        if(power&&r.durationUs)s.power.nodes.at(power).demandW+=std::uint32_t((r.energyUj*j.batch+r.durationUs-1)/r.durationUs);
    }
    auto energy=allocate_power(s.power,dt);
    for(auto& [id,j]:s.crafting.jobs) {
        (void)id;if(j.phase!=JobPhase::Running&&j.phase!=JobPhase::Paused)continue;auto& r=d.recipes.at(j.recipe);
        auto power=s.crafting.stations.at(j.station).powerNode;auto available=power?energy.deliveredUj[power]:0;
        auto outputs=craft_output_budget(d,j,dt);
        auto before=j.energyUj;bool tools=true;for(auto tool:j.tools)tools&=w.items.at(tool).durability>0;
        if(!tools){j.phase=JobPhase::Paused;continue;}
        advance_craft(d.items,w,s.crafting,j,r,dt,available,ids.take(outputs),event);
        if(power)energy.deliveredUj[power]-=j.energyUj-before;
        if(j.phase==JobPhase::OutputReady){auto& rows=s.unlocks[j.owner];if(!std::binary_search(rows.begin(),rows.end(),r.id)){rows.push_back(r.id);std::sort(rows.begin(),rows.end());}}
    }
    std::map<Id,Life> active;std::vector<Observer> observers;
    for(auto& cell:s.world.cells){cell.pins.fill(0);cell.savedRevision=cell.dirtyRevision;}
    for(auto& [id,l]:s.lives)if(active_player(s.controls.at(id),s.tick)){
        active.emplace(id,l);if(l.status!=LifeStatus::Dead){observers.push_back({l.position,bool(s.controls.at(id).vehicle)});pin(s.world.cells[cell_of(l.position)],PinReason::Player,1);}
    }
    for(auto& shot:s.shots){auto& p=shot.flight.projectile.flight.position;if(std::abs(p[0])<=2000000000&&std::abs(p[1])<=2000000000)pin(s.world.cells[cell_of({p[0]/1e6,p[1]/1e6,p[2]/1e6})],PinReason::Projectile,1);}
    for(auto& [id,j]:s.crafting.jobs)if(j.phase==JobPhase::Running||j.phase==JobPhase::Paused){
        (void)id;auto position=s.crafting.stations.at(j.station).position;pin(s.world.cells[cell_of(position)],PinReason::Craft,1);
        if(j.phase==JobPhase::Running&&s.tick%6==0)publish_stimulus(s.world,{(event^j.station.lo)|1,s.tick,j.station,position,StimulusKind::Machine,100,85,500,6});
    }
    if(s.tick%6==0)for(auto& [id,v]:s.vehicles)if(v.running)publish_stimulus(s.world,{(event^id.lo)|1,s.tick,id,v.position,StimulusKind::Engine,200,100,1000,6});
    auto wanted=active_cells(observers);
    for(unsigned i=0;i<1024;++i){auto& cell=s.world.cells[i];cell.wanted=wanted[i];if(cell.wanted||!can_unload(cell))cell.loaded=true;else cell.loaded=false;}
    auto attacks=update_zombies(s.world,active,s.structures,d.structures,s.world.stimuli,s.tick);s.world.stimuli.clear();
    for(auto hit:attacks)wound(s.lives.at(hit.victim),0x8000000000000000ULL|((event&0x1fffffffffffffULL)<<10)|(hit.zombie.lo%1024),Region::Thorax,50,true);
    for(auto& [id,b]:s.structures)if(b.armed&&!b.destroyed&&s.tick-b.lastTriggerTick>=180) {
        for(auto& [zid,z]:s.world.zombies)if(z.health&&length(z.position-b.position)<1){z.health=std::max(0.0,z.health-50);b.lastTriggerTick=s.tick;++b.revision;(void)id;(void)zid;break;}
    }
    for(auto id:unsupported(s.structures,d.structures)){auto& b=s.structures.at(id);b.destroyed=true;b.health=0;b.removedTick=s.tick;++b.revision;}
    tick_ground(d,w,s,ids,event);
}
}
