#include "game_execution.hpp"
#include "mutation.hpp"
namespace astra {
void finish_stations(const GameDefinitions& d,World& w,GameState& s,GameIds& ids,std::uint64_t event) {
    for(auto& [id,station]:s.crafting.stations) {
        if(s.structures.contains(id)&&s.structures.at(id).destroyed)station.destroyed=true;
        if(!station.destroyed||station.wreck)continue;
        for(auto& [jobId,job]:s.crafting.jobs)if(job.station==id&&(job.phase==JobPhase::Running||job.phase==JobPhase::Paused||job.phase==JobPhase::OutputReady)) {
            (void)jobId;cancel_craft(d.items,w,s.crafting,job,true);
        }
        auto wreck=ids.take();ItemState item;item.id=wreck;item.defId=120;item.birthEvent=event;
        require(w.items.emplace(wreck,item).second,Error::InvalidState);place_item(d.items,w,wreck,ground_root);
        for(auto& [cid,c]:w.containers)if(c.state.ownerItem==station.item){(void)cid;c.state.ownerItem=wreck;bump(c.state.revision);}
        auto& bench=w.items.at(station.item);bench.quantity=0;bench.flags|=deleted;bump(bench.revision);w.placements.erase(station.item);
        station.wreck=wreck;++station.revision;if(station.powerNode){auto& node=s.power.nodes.at(station.powerNode);node.demandW=0;node.generateW=0;node.fuelUj=0;}
        s.groundAssets.emplace(wreck,GroundAsset{wreck,station.owner,station.position});
    }
}
}
