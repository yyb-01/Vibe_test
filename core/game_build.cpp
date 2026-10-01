#include "game_execution.hpp"
#include "mutation.hpp"
namespace astra {
void build_utility(const GameDefinitions&,World&,GameState&,const Structure&,unsigned,GameIds&,std::uint64_t);
bool building_action(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds& ids,std::uint64_t event) {
    auto& life=s.lives.at(p.actor);
    if(c.operation==GameOperation::Build) {
        require(d.structures.contains(c.definition),Error::Incompatible);auto& def=d.structures.at(c.definition);
        Structure b;b.entity=ids.take();b.owner=p.account;b.definition=def.id;b.position=normalize_build(c.position);b.health=def.health;b.bornTick=s.tick;
        if(c.targets[0])b.supports.push_back({c.targets[0],65535,def.capacityG});
        bool allowed=true,clear=true;
        for(auto& [id,other]:s.structures){(void)id;if(!other.destroyed&&other.owner!=p.account&&length(other.position-b.position)<10)allowed=false;}
        for(auto& [id,l]:s.lives)if(active_player(s.controls.at(id),s.tick)&&l.status!=LifeStatus::Dead&&length(l.position-b.position)<.5)clear=false;
        validate_build(b,def,s.structures,d.structures,{life.position,0,0,true,clear,allowed,line_of_sight(life.position+Vec3{0,0,1},b.position,s.structures,d.structures)});
        for(auto [material,n]:def.materials)take_materials(w,life.inventory,material,n);
        require(s.structures.emplace(b.entity,b).second,Error::InvalidState);
        require(unsupported(s.structures,d.structures).empty(),Error::CapacityExceeded);
        if(c.definition>=17&&c.definition<=19)build_utility(d,w,s,b,c.quantity,ids,event);
        return true;
    }
    if(c.operation!=GameOperation::Destroy&&c.operation!=GameOperation::Door&&c.operation!=GameOperation::ArmTrap&&c.operation!=GameOperation::Lock)return false;
    if(c.operation==GameOperation::Destroy&&s.crafting.stations.contains(c.targets[0])&&!s.structures.contains(c.targets[0])) {
        auto& station=s.crafting.stations.at(c.targets[0]);require(station.owner==p.account&&!station.destroyed&&length(life.position-station.position)<=3,Error::NotAccessible);
        station.destroyed=true;++station.revision;return true;
    }
    require(s.structures.contains(c.targets[0]),Error::NotAccessible);auto& b=s.structures.at(c.targets[0]);auto kind=d.structures.at(b.definition).kind;
    require(!b.destroyed&&b.owner==p.account&&length(life.position-b.position)<=3,Error::NotAccessible);
    if(c.operation==GameOperation::Destroy){b.destroyed=true;b.health=0;b.lastDamageEvent=event;b.removedTick=s.tick;}
    else if(c.operation==GameOperation::Lock){require(kind==StructureKind::Door||(s.crafting.stations.contains(b.entity)&&!s.crafting.stations.at(b.entity).capabilities),Error::Incompatible);b.locked=c.enabled;if(kind==StructureKind::Door&&c.enabled)b.open=false;}
    else if(c.operation==GameOperation::Door){require(kind==StructureKind::Door&&(!c.enabled||!b.locked),Error::NotAccessible);b.open=c.enabled;}
    else {require(kind==StructureKind::Trap,Error::Incompatible);b.armed=c.enabled;}
    ++b.revision;return true;
}
}
