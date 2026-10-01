#include "game_execution.hpp"
#include "game_flags.hpp"
namespace astra {
void take_materials(World& w,Id source,std::uint32_t def,std::uint64_t need) {
    for(auto& [id,i]:w.items)if(i.defId==def&&belongs_to(w,id,source)&&!(i.flags&leased_tool)) {
        auto n=std::uint32_t(std::min<std::uint64_t>(need,i.quantity));if(n)consume_item(w,id,n);need-=n;if(!need)break;
    }
    require(!need,Error::InvalidQuantity);
}
bool economy_action(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds& ids,std::uint64_t event) {
    auto& life=s.lives.at(p.actor);auto& craft=s.crafting;
    switch(c.operation) {
    case GameOperation::Craft: {
        require(d.recipes.contains(c.definition)&&craft.stations.contains(c.targets[0]),Error::Incompatible);
        auto& station=craft.stations.at(c.targets[0]);require(length(station.position-life.position)<=3,Error::NotAccessible);
        std::set<std::uint32_t> unlocks(s.unlocks[p.account].begin(),s.unlocks[p.account].end());auto& recipe=d.recipes.at(c.definition);
        for(auto input:recipe.inputs)for(auto& [id,item]:w.items)if(item.defId==input.def&&w.placements.contains(id)&&w.placements.at(id).container==life.inventory)require(!reload_busy(w,s,id),Error::Busy);
        for(auto prereq:recipe.prerequisites)require(unlocks.contains(prereq),Error::NotAccessible);
        start_craft(d.items,w,craft,recipe,station.entity,p.account,life.inventory,c.id,c.quantity,ids.take(34),event,unlocks);return true;
    }
    case GameOperation::Cancel:case GameOperation::Collect: {
        require(craft.jobs.contains(c.targets[0])&&craft.jobs.at(c.targets[0]).owner==p.account,Error::NotAccessible);auto& j=craft.jobs.at(c.targets[0]);
        require(length(craft.stations.at(j.station).position-life.position)<=3,Error::NotAccessible);
        if(c.operation==GameOperation::Cancel)cancel_craft(d.items,w,craft,j,false);else collect_craft(d.items,w,j,life.inventory);return true;
    }
    case GameOperation::ConnectPower: {
        require(s.power.nodes.contains(c.targets[0])&&s.power.nodes.contains(c.targets[1])&&length(s.power.nodes.at(c.targets[0]).position-life.position)<=3&&
            length(s.power.nodes.at(c.targets[1]).position-life.position)<=3,Error::NotAccessible);
        take_materials(w,life.inventory,109,1);s.power.cables.push_back({c.targets[0],c.targets[1],10});auto check=s.power;allocate_power(check,1);return true;
    }
    case GameOperation::Refuel: {
        if(s.vehicles.contains(c.targets[0])){
            auto& v=s.vehicles.at(c.targets[0]);require(length(v.position-life.position)<=3&&length(v.velocity)<1&&c.quantity<=100&&v.fuelUl<=100000000-std::uint64_t(c.quantity)*1000000,Error::NotAccessible);
            take_materials(w,life.inventory,124,c.quantity);v.fuelUl+=std::uint64_t(c.quantity)*1000000;++v.revision;return true;
        }
        require(s.power.nodes.contains(c.targets[0])&&length(s.power.nodes.at(c.targets[0]).position-life.position)<=3&&c.quantity<=100,Error::NotAccessible);
        auto& node=s.power.nodes.at(c.targets[0]);require(!node.renewable&&node.fuelUj<=1000000000000000ULL-std::uint64_t(c.quantity)*1000000000,Error::CapacityExceeded);
        take_materials(w,life.inventory,108,c.quantity);node.fuelUj+=std::uint64_t(c.quantity)*1000000000;return true;
    }
    default:return false;
    }
}
}
