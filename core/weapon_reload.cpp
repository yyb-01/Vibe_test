#include "weapons.hpp"
#include "magazine.hpp"
#include "crafting.hpp"
#include "mutation.hpp"
namespace astra {
void feed_round(const Catalog& cat,World& w,Id weapon,Id magazine,Id created,std::uint64_t event,const std::map<std::uint32_t,AmmoProfile>& ammo,const ReceiverProfile& receiver) {
    auto request=feed_request(w,weapon,magazine,{1,1},1,1);auto round=request.moves[0].item;
    require(ammo.contains(w.items.at(round).defId),Error::Incompatible);auto& profile=ammo.at(w.items.at(round).defId);
    require(profile.family==receiver.family&&profile.chamberProfile==receiver.chamberProfile,Error::Incompatible);
    mutate(cat,w,request,created,event);
}
void begin_reload(WeaponRuntime& state,const World& w,Id magazine,const ReceiverProfile& d,std::uint64_t tick) {
    require(state.phase==WeaponPhase::Ready||state.phase==WeaponPhase::Idle,Error::Busy);
    require(w.items.contains(magazine)&&magazine_state(w,magazine).container,Error::Incompatible);
    state.selectedMagazine=magazine;state.oldMagazine={};state.phase=WeaponPhase::ExtractMagazine;state.nextPhaseTick=tick+d.reloadStepTicks;state.trigger=false;++state.revision;
}
void step_reload(const Catalog& cat,World& w,WeaponRuntime& state,const ReceiverProfile& d,std::uint64_t tick,Id bag,Id created,std::uint64_t event,const std::map<std::uint32_t,AmmoProfile>& ammo) {
    if(tick<state.nextPhaseTick||state.phase==WeaponPhase::Ready||state.phase==WeaponPhase::Idle||state.phase==WeaponPhase::Jammed)return;
    Id mount{};for(auto& [id,c]:w.containers)if(c.state.ownerItem==state.item&&c.kind==PlaceKind::Slot&&!(c.state.flags&(chamber_container|magazine_container)))mount=id;
    require(bool(mount),Error::Incompatible);
    if(state.phase==WeaponPhase::ExtractMagazine) {
        for(auto& [id,p]:w.placements)if(p.container==mount){state.oldMagazine=id;break;}
        if(state.oldMagazine){place_item(cat,w,state.oldMagazine,bag);bump(w.items.at(state.oldMagazine).revision);}
        state.phase=WeaponPhase::InsertMagazine;
    } else if(state.phase==WeaponPhase::InsertMagazine) {
        require(w.placements.contains(state.selectedMagazine)&&w.placements.at(state.selectedMagazine).container==bag,Error::NotAccessible);
        auto& item=w.items.at(state.selectedMagazine);w.placements.at(item.id)={item.id,mount,1,0,0,0,PlaceKind::Slot};bump(item.revision);state.phase=WeaponPhase::Chamber;
    } else {
        if(!chamber_state(w,state.item).round&&magazine_state(w,state.selectedMagazine).nextRound)feed_round(cat,w,state.item,state.selectedMagazine,created,event,ammo,d);
        state.phase=WeaponPhase::Ready;state.oldMagazine={};
    }
    state.nextPhaseTick=tick+d.reloadStepTicks;++state.revision;
}
}
