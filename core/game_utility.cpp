#include "game_execution.hpp"
namespace astra {
void build_utility(const GameDefinitions& d,World& w,GameState& s,const Structure& b,unsigned tier,GameIds& ids,std::uint64_t event){
    require(tier>=1&&tier<=4,Error::InvalidRequest);
    Station station;station.entity=b.entity;station.item=ids.take();station.output=ids.take();station.powerNode=ids.take();
    station.owner=b.owner;station.position=b.position;station.capabilities=b.definition==18?1u<<(tier-1):0;
    ItemState item;item.id=station.item;item.defId=115;item.birthEvent=event;require(w.items.emplace(item.id,item).second,Error::InvalidState);place_item(d.items,w,item.id,station_root);
    Container c;c.state.id=station.output;c.state.ownerItem=item.id;c.state.width=c.state.height=16;c.state.capacityMl=100000;c.maxMassG=100000;
    require(w.containers.emplace(c.state.id,c).second&&s.crafting.stations.emplace(station.entity,station).second,Error::InvalidState);
    PowerNode power;power.entity=station.powerNode;power.position=b.position;if(b.definition==19)power.generateW=5000;
    require(s.power.nodes.emplace(power.entity,power).second,Error::InvalidState);
}
bool accessible_container(const GameDefinitions& d,const World& w,const GameState& s,Id actor,Id container){
    if(!w.containers.contains(container)||!s.lives.contains(actor))return false;
    auto& life=s.lives.at(actor);auto path=ancestry(w,container);if(path.back()==life.inventory)return true;
    if(path.back()!=station_root)return false;
    for(auto& [id,station]:s.crafting.stations)if(!station.capabilities&&!station.destroyed&&std::find(path.begin(),path.end(),station.output)!=path.end()){
        if(!s.structures.contains(id))return false;auto& b=s.structures.at(id);
        return !b.destroyed&&(!b.locked||b.owner==life.account)&&length(life.position-station.position)<=3&&
            line_of_sight(life.position+Vec3{0,0,1},station.position+Vec3{0,0,1},s.structures,d.structures);
    }
    return false;
}
}
