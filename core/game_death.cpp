#include "game_execution.hpp"
#include "mutation.hpp"
namespace astra {
void finish_deaths(const GameDefinitions& d,World& w,GameState& s,GameIds& ids,std::uint64_t event) {
    for(auto& [actor,l]:s.lives) {
        if(l.status!=LifeStatus::Dead||l.corpse)continue;
        for(auto& [id,weapon]:s.weapons){(void)id;if(weapon.owner==l.account){weapon.trigger=false;abort_reload(w,weapon);}}
        auto body=ids.take(),container=ids.take();ItemState item;item.id=body;item.defId=120;item.birthEvent=event;
        require(d.items.contains(item.defId)&&w.items.emplace(body,item).second,Error::InvalidState);place_item(d.items,w,body,ground_root);
        Container corpse;corpse.state.id=container;corpse.state.ownerItem=body;corpse.state.width=corpse.state.height=32;
        corpse.state.capacityMl=UINT32_MAX;corpse.kind=PlaceKind::Escrow;require(w.containers.emplace(container,corpse).second,Error::InvalidState);
        for(auto& [id,placement]:w.placements)if(placement.container==l.inventory) {
            placement={id,container,0,0,0,0,PlaceKind::Escrow};bump(w.items.at(id).revision);
        }
        for(auto& [jobId,job]:s.crafting.jobs) {
            (void)jobId;if(job.owner==l.account&&(job.phase==JobPhase::Running||job.phase==JobPhase::Paused))cancel_craft(d.items,w,s.crafting,job,false);
        }
        auto& control=s.controls.at(actor);if(control.vehicle){s.vehicles.at(control.vehicle).driver={};control.vehicle={};}
        l.corpse=body;++l.revision;s.groundAssets.emplace(body,GroundAsset{body,l.account,l.position,{},{},l.epoch});
    }
}
}
