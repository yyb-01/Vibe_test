#include "crafting.hpp"
#include "mutation.hpp"
#include "game_flags.hpp"
namespace astra {
CraftJob start_craft(const Catalog&,World& w,Crafting& c,const Recipe& r,Id station,Id owner,Id source,Id request,std::uint32_t batch,Id first,std::uint64_t event,const std::set<std::uint32_t>& unlocks) {
    require(c.stations.contains(station)&&owner&&batch&&batch<=100&&(!r.repairDef||batch==1),Error::InvalidRequest);
    auto& s=c.stations.at(station);require(!s.destroyed&&(!s.owner||s.owner==owner)&&(s.capabilities&r.capabilities)==r.capabilities&&(!r.unlock||unlocks.contains(r.unlock)),Error::NotAccessible);
    unsigned queued=0,owned=0;
    for(auto& [id,j]:c.jobs){(void)id;if(j.phase==JobPhase::Running||j.phase==JobPhase::Paused){queued+=j.station==station;owned+=j.owner==owner;}}
    require(queued<16&&owned<8&&w.containers.contains(source),Error::LimitExceeded);
    CraftJob job;job.entity=first;job.request=request;job.station=station;job.owner=owner;job.source=source;
    job.escrow={first.hi,first.lo+1};job.recipe=r.id;job.version=r.version;job.batch=batch;job.seed=event^first.hi^first.lo;
    Container escrow;escrow.state.id=job.escrow;escrow.state.ownerItem=s.item;escrow.state.width=escrow.state.height=32;
    escrow.state.capacityMl=UINT32_MAX;escrow.kind=PlaceKind::Escrow;require(w.containers.emplace(job.escrow,escrow).second,Error::InvalidState);
    auto next=first.lo+2;
    for(auto input:r.inputs) {
        std::uint64_t need=std::uint64_t(input.quantity)*batch;
        std::vector<Id> candidates;
        for(auto& [id,i]:w.items)if(!(i.flags&deleted)&&i.defId==input.def&&i.durability>=input.minCondition&&(!r.repairDef||i.defId!=r.repairDef||i.durability<65535)&&w.placements.contains(id)&&w.placements.at(id).container==source&&!c.toolLeases.contains(id))candidates.push_back(id);
        for(auto id:candidates) {
            if(!need)break;auto& i=w.items.at(id);auto count=std::uint32_t(std::min<std::uint64_t>(i.quantity,need));Id moved=id;
            if(count<i.quantity) {
                require(i.extraIndex==UINT32_MAX,Error::InvalidQuantity);auto part=i;part.id={first.hi,next++};part.quantity=count;part.revision=1;part.birthEvent=event;
                moved=part.id;require(w.items.emplace(moved,part).second,Error::InvalidState);i.quantity-=count;bump(i.revision);
            }else bump(i.revision);
            w.placements.insert_or_assign(moved,Placement{moved,job.escrow,0,0,0,0,PlaceKind::Escrow});job.inputs.push_back(moved);need-=count;
        }
        require(!need&&job.inputs.size()<=32,Error::InvalidQuantity);
    }
    for(auto tool:r.tools) {
        Id chosen{};
        for(auto& [id,i]:w.items)if(!(i.flags&deleted)&&i.defId==tool.def&&i.durability&&w.placements.contains(id)&&w.placements.at(id).container==source&&!c.toolLeases.contains(id)){chosen=id;break;}
        require(bool(chosen),Error::Incompatible);c.toolLeases.emplace(chosen,job.entity);job.tools.push_back(chosen);
        w.items.at(chosen).flags|=leased_tool;bump(w.items.at(chosen).revision);
    }
    require(c.jobs.emplace(job.entity,job).second,Error::InvalidState);return job;
}
}
