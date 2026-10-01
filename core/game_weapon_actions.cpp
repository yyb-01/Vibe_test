#include "game_execution.hpp"
#include "mutation.hpp"
#include "magazine.hpp"
namespace astra {
void perform_shot(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t,bool);
static Id assembly_weapon(const World& w,const GameState& s,Id item) {
    for(unsigned depth=0;item&&depth<8;++depth) {
        if(s.weapons.contains(item))return item;
        require(w.placements.contains(item),Error::NotAccessible);item=w.containers.at(w.placements.at(item).container).state.ownerItem;
    }return {};
}
bool combat_action(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds& ids,std::uint64_t event) {
    auto bag=actor_inventory(s,p);
    if(c.operation==GameOperation::Attach||c.operation==GameOperation::Detach) {
        require(belongs_to(w,c.targets[0],bag),Error::NotAccessible);auto weapon=assembly_weapon(w,s,c.targets[0]);
        if(c.operation==GameOperation::Attach) {
            require(w.containers.contains(c.targets[1])&&belongs_to(w,w.containers.at(c.targets[1]).state.ownerItem,bag)&&w.placements.at(c.targets[0]).kind!=PlaceKind::Socket,Error::NotAccessible);
            weapon=assembly_weapon(w,s,w.containers.at(c.targets[1]).state.ownerItem);attach_part(d.items,w,c.targets[0],c.targets[1],c.definition,d.parts);
        } else {require(w.placements.at(c.targets[0]).kind==PlaceKind::Socket,Error::NotAccessible);place_item(d.items,w,c.targets[0],bag);bump(w.items.at(c.targets[0]).revision);}
        require(bool(weapon),Error::Incompatible);auto& state=s.weapons.at(weapon);
        require(state.phase==WeaponPhase::Ready||state.phase==WeaponPhase::Idle,Error::Busy);weapon_stats(d.items,w,weapon,d.parts,false);
        ++state.assemblyRevision;++state.revision;return true;
    }
    if(c.operation!=GameOperation::Fire&&c.operation!=GameOperation::Reload&&c.operation!=GameOperation::Trigger&&c.operation!=GameOperation::ClearJam)return false;
    require(s.weapons.contains(c.targets[0])&&belongs_to(w,c.targets[0],bag),Error::NotAccessible);auto& state=s.weapons.at(c.targets[0]);
    require(state.owner==p.account&&c.revision==state.assemblyRevision,Error::RevisionConflict);
    auto& receiver=d.receivers.at(d.items.at(w.items.at(state.item).defId).partDefId);
    if(c.operation==GameOperation::Reload) {
        require(belongs_to(w,c.targets[1],bag)&&w.placements.at(c.targets[1]).container==bag&&!reload_busy(w,s,c.targets[1]),Error::NotAccessible);
        auto magazine=magazine_state(w,c.targets[1]);
        for(auto& [id,place]:w.placements)if(place.container==magazine.container){auto def=w.items.at(id).defId;require(d.ammunition.contains(def),Error::Incompatible);auto& ammo=d.ammunition.at(def);require(ammo.family==receiver.family&&ammo.chamberProfile==receiver.chamberProfile,Error::Incompatible);}
        begin_reload(state,w,c.targets[1],receiver,s.tick);
    } else if(c.operation==GameOperation::ClearJam) {
        require(state.phase==WeaponPhase::Jammed,Error::InvalidRequest);state.phase=WeaponPhase::Ready;state.fouling=std::max(0.0,state.fouling-.1);++state.revision;
    } else if(c.operation==GameOperation::Trigger) {
        require(receiver.automatic&&state.phase==WeaponPhase::Ready&&std::int32_t(c.sequence-state.inputSeq)>0,Error::NotAccessible);
        state.trigger=c.enabled;state.inputSeq=c.sequence;++state.revision;
    } else perform_shot(d,w,s,c,p,ids,event,false);
    return true;
}
}
