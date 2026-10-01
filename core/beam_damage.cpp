#include "beam_scene.hpp"
#include "mutation.hpp"
namespace astra {
void apply_beam_damage(GameState& s,GameShot& shot,std::span<const BeamDeposit> deposits,World* world) {
    for(auto& d:deposits) {
        require(d.energyUj>=0&&d.target.contact&&d.target.contact<=16,Error::InvalidState);
        auto& t=d.target;auto& total=shot.damageUj[t.contact];auto previous=total;require(d.energyUj<=2000000000000LL-total,Error::InvalidState);total+=d.energyUj;
        auto event=(shot.flight.projectile.shotId<<5)|t.contact;
        if(t.kind==4) {
            if(s.armor.contains(t.armor))damage_armor_progress(s.armor.at(t.armor),t.u,t.v,total/1000000.0,previous/1000000.0,.12);
        } else if(t.kind==0&&s.lives.contains(t.entity)&&s.lives.at(t.entity).epoch==t.epoch) {
            wound_progress(s.lives.at(t.entity),event,Region(t.region),total/1000000.0,t.vital,previous/1000000.0);
        } else if(t.kind==1&&s.world.zombies.contains(t.entity)) {
            auto& z=s.world.zombies.at(t.entity);z.health=t.vital?0:std::max(0.0,z.health-d.energyUj*.1/1000000);++z.revision;
        } else if(t.kind==2&&world&&s.vehicles.contains(t.entity)){
            auto& item=world->items.at(t.entity);auto loss=total/1000000-previous/1000000;
            item.durability=std::uint16_t(std::max(std::int64_t{0},std::int64_t(item.durability)-loss));if(loss)bump(item.revision);
            if(!item.durability){auto& v=s.vehicles.at(t.entity);v.running=false;v.torquePath=false;++v.revision;}
        } else if(t.kind==3&&s.structures.contains(t.entity)) {
            auto& b=s.structures.at(t.entity);b.health=std::uint16_t(std::max(0.0,b.health-d.energyUj*.02/1000000));b.lastDamageEvent=event;
            if(!b.health){b.destroyed=true;b.removedTick=s.tick;}++b.revision;
        }
    }
}
}
