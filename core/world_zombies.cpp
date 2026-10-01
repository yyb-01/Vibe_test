#include "world_simulation.hpp"
namespace astra {
std::vector<ZombieAttack> update_zombies(WorldSimulation& world,const std::map<Id,Life>& lives,const std::map<Id,Structure>& structures,
    const std::map<std::uint32_t,StructureDef>& defs,std::span<const Stimulus> stimuli,std::uint64_t tick) {
    require(world.zombies.size()<=800&&world.pathBudget<=64,Error::LimitExceeded);std::vector<ZombieAttack> attacks;unsigned paths=0;
    for(auto& [id,z]:world.zombies) {
        require(id==z.entity&&id&&finite(z.position)&&z.health>=0,Error::InvalidState);
        if(z.health==0){z.mode=ZombieMode::Dead;continue;}
        if(!world.cells[cell_of(z.position)].wanted)continue;
        for(auto s:stimuli) {
            auto distance=length(z.position-s.position);if(distance>s.radiusM||s.event==z.lastStimulus||s.kind==StimulusKind::Heat)continue;
            auto db=s.soundDb-20*std::log10(std::max(1.0,distance))-(line_of_sight(z.position,s.position,structures,defs)?0:15);
            if(db>=z.hearingDb){z.investigate=s.position;z.mode=ZombieMode::Investigate;z.lastStimulus=s.event;}
        }
        Id target{};double nearest=50;
        for(auto& [other,life]:lives) {
            auto distance=length(life.position-z.position);
            if(life.status!=LifeStatus::Dead&&distance<nearest&&line_of_sight(z.position,life.position,structures,defs)){nearest=distance;target=other;}
        }
        if(target){z.target=target;z.investigate=lives.at(target).position;z.mode=nearest<1.5?ZombieMode::Attack:ZombieMode::Chase;}
        else z.target={};
        if(z.mode==ZombieMode::Attack&&target&&tick-z.lastAttackTick>=60){attacks.push_back({id,target,tick});z.lastAttackTick=tick;++z.revision;}
        if(tick%(nearest<30?6:30)||z.mode==ZombieMode::Idle||z.mode==ZombieMode::Attack)continue;
        Vec3 destination=z.investigate;
        if(!line_of_sight(z.position,destination,structures,defs)) {
            if(paths++>=world.pathBudget)continue;auto route=find_path(z.position,destination,structures,defs);if(route.empty())continue;destination=route.front();
        }
        auto delta=destination-z.position;auto range=length(delta),dt=nearest<30?.1:.5;
        if(range>.01)z.position=z.position+delta*(std::min(range,z.speedMS*dt)/range);else z.mode=ZombieMode::Idle;
        ++z.revision;
    }return attacks;
}
}
