#include "game_execution.hpp"
#include "mutation.hpp"
#include "game_flags.hpp"
namespace astra {
bool ground_action(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds& ids,std::uint64_t event) {
    if(c.operation!=GameOperation::Loot)return false;auto& life=s.lives.at(p.actor);auto item=c.targets[0];
    require(belongs_to(w,item,ground_root)&&!s.vehicles.contains(item)&&!s.structures.contains(item),Error::NotAccessible);
    auto path=ancestry(w,w.placements.at(item).container);Id rootItem=item;
    if(path.size()>1)rootItem=w.containers.at(path[path.size()-2]).state.ownerItem;
    auto asset=std::find_if(s.groundAssets.begin(),s.groundAssets.end(),[&](auto& row){return row.second.item==rootItem;});
    require(asset!=s.groundAssets.end()&&length(life.position-asset->second.position)<=3&&line_of_sight(life.position,asset->second.position,s.structures,d.structures),Error::NotAccessible);
    for(auto& [id,j]:s.crafting.jobs){(void)id;if(w.placements.at(item).container==j.escrow)require(j.owner==p.account&&j.phase!=JobPhase::Running&&j.phase!=JobPhase::Paused,Error::NotAccessible);}
    auto& original=w.items.at(item);require(c.quantity<=original.quantity&&!(original.flags&leased_tool),Error::InvalidQuantity);Id moved=item;
    if(c.quantity<original.quantity) {
        require(!d.items.at(original.defId).containerDefId,Error::InvalidQuantity);auto split=original;split.id=ids.take();split.quantity=c.quantity;split.revision=1;split.birthEvent=event;
        require(w.items.emplace(split.id,split).second,Error::InvalidState);original.quantity-=c.quantity;bump(original.revision);moved=split.id;
    }else {
        if(rootItem==item)asset->second.item={};bump(original.revision);
    }
    place_item(d.items,w,moved,life.inventory);
    if(s.weapons.contains(moved)){auto& weapon=s.weapons.at(moved);require(weapon.generation<UINT16_MAX,Error::LimitExceeded);weapon.owner=p.account;++weapon.generation;++weapon.revision;}
    return true;
}
void tick_ground(const GameDefinitions& d,World& w,GameState& s,GameIds& ids,std::uint64_t event) {
    for(auto& [id,a]:s.groundAssets) {
        (void)id;
        if(a.item) {
            a.velocity=a.velocity+Vec3{0,0,-9.80665/60};a.position=a.position+a.velocity/60;
            if(a.position.z<0){a.position.z=0;a.velocity={};a.omega={};}
        } else if(a.spawnDef&&s.tick>=a.nextSpawnTick&&s.world.cells[cell_of(a.position)].wanted) {
            bool clear=true;for(auto& [actor,l]:s.lives)if(active_player(s.controls.at(actor),s.tick)&&l.status!=LifeStatus::Dead&&length(l.position-a.position)<10)clear=false;
            if(!clear)continue;
            ItemState item;item.id=ids.take();item.defId=a.spawnDef;item.quantity=a.quantity;item.birthEvent=event;
            require(w.items.emplace(item.id,item).second,Error::InvalidState);place_item(d.items,w,item.id,ground_root);a.item=item.id;++a.cycle;a.nextSpawnTick=s.tick+18000;
        }
    }
}
}
