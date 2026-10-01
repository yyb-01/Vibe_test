#include "game_execution.hpp"
#include "inventory.hpp"
#include "game_flags.hpp"
namespace astra {
void validate_game_world(const GameDefinitions& d,const World& w,const GameState& s) {
    require(s.catalogVersion==d.version&&s.controls.size()==s.lives.size(),Error::Incompatible);
    for(auto& [id,l]:s.lives)require(w.containers.contains(l.inventory)&&!w.containers.at(l.inventory).state.ownerItem&&s.controls.contains(id)&&
        s.controls.at(id).moveTick<=s.tick&&s.controls.at(id).aimTick<=s.tick,Error::InvalidState);
    for(auto& [id,weapon]:s.weapons){require(w.items.contains(id)&&d.receivers.contains(d.items.at(w.items.at(id).defId).partDefId),Error::Incompatible);(void)weapon;}
    for(auto& [id,c]:s.controls){auto bag=s.lives.at(id).inventory;require((!c.weapon||belongs_to(w,c.weapon,bag))&&(!c.armor||belongs_to(w,c.armor,bag)),Error::InvalidState);}
    for(auto& [id,station]:s.crafting.stations){(void)id;require((station.destroyed?w.items.contains(station.wreck):w.items.contains(station.item))&&w.containers.contains(station.output)&&
        (!station.powerNode||s.power.nodes.contains(station.powerNode)),Error::InvalidState);}
    for(auto& [id,j]:s.crafting.jobs) {
        (void)id;require(d.recipes.contains(j.recipe)&&d.recipes.at(j.recipe).version==j.version&&w.containers.contains(j.escrow)&&w.containers.at(j.escrow).kind==PlaceKind::Escrow,Error::Incompatible);
        auto& r=d.recipes.at(j.recipe);require(j.stage<=r.stages.size()&&j.progressUs<=r.durationUs&&j.energyUj<=r.energyUj*j.batch,Error::InvalidState);
        for(auto item:j.inputs)require(w.items.contains(item),Error::InvalidState);
        if(j.phase==JobPhase::Running||j.phase==JobPhase::Paused)for(auto tool:j.tools)require(w.items.contains(tool),Error::InvalidState);
    }
    for(auto& [tool,job]:s.crafting.toolLeases){(void)job;require(w.items.contains(tool)&&(w.items.at(tool).flags&leased_tool),Error::InvalidState);}
    for(auto& [id,i]:w.items)if(i.flags&leased_tool)require(s.crafting.toolLeases.contains(id),Error::InvalidState);
    for(auto& [id,b]:s.structures){(void)id;require(d.structures.contains(b.definition)&&b.health<=d.structures.at(b.definition).health,Error::Incompatible);}
    for(auto& shot:s.shots)require(d.ammunition.contains(shot.ammoDef),Error::Incompatible);
    for(auto& [id,v]:s.vehicles){(void)id;for(auto& part:v.parts)require(w.items.contains(part.item),Error::InvalidState);require(v.wheels.size()==d.wheels.size(),Error::Incompatible);}
}
}
