#include "game_execution.hpp"
#include "chamber.hpp"
namespace astra {
static bool reloading(const WeaponRuntime& w){return w.phase>=WeaponPhase::ExtractMagazine&&w.phase<=WeaponPhase::Chamber;}
bool reload_busy(const World& w,const GameState& s,Id item){
    for(unsigned depth=0;item&&depth<9;++depth){
        for(auto& [id,weapon]:s.weapons)if(reloading(weapon)&&(item==id||item==weapon.selectedMagazine||item==weapon.oldMagazine))return true;
        if(!w.placements.contains(item))break;
        item=w.containers.at(w.placements.at(item).container).state.ownerItem;
    }
    return false;
}
void check_reload_access(const World& w,const GameState& s,const GameCommand& c){
    if(c.operation!=GameOperation::Attach&&c.operation!=GameOperation::Detach&&
       !(c.operation>=GameOperation::InventoryMove&&c.operation<=GameOperation::Drop))return;
    require(!reload_busy(w,s,c.targets[0]),Error::Busy);
    auto target=c.targets[1];if(w.containers.contains(target))target=w.containers.at(target).state.ownerItem;
    require(!reload_busy(w,s,target),Error::Busy);
}
void abort_reload(const World& w,WeaponRuntime& weapon){
    if(!reloading(weapon))return;
    weapon.phase=chamber_state(w,weapon.item).round?WeaponPhase::Ready:WeaponPhase::Idle;
    weapon.selectedMagazine={};weapon.oldMagazine={};
    for(auto& [id,p]:w.placements)if(w.containers.at(p.container).state.ownerItem==weapon.item&&
        p.kind==PlaceKind::Slot&&!(w.containers.at(p.container).state.flags&(chamber_container|magazine_container)))weapon.selectedMagazine=id;
    ++weapon.revision;
}
}
