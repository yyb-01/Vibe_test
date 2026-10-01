#include "game_execution.hpp"
#include "chamber.hpp"
namespace astra {
void perform_shot(const GameDefinitions&,World&,GameState&,const GameCommand&,const GamePeer&,GameIds&,std::uint64_t,bool);
void tick_weapons(const GameDefinitions& d,World& w,GameState& s,GameIds& ids,std::uint64_t event) {
    for(auto& [id,weapon]:s.weapons) {
        auto actor=std::find_if(s.lives.begin(),s.lives.end(),[&](auto& row){return row.second.account==weapon.owner;});
        if(actor==s.lives.end()||!s.controls.at(actor->first).connected||actor->second.status!=LifeStatus::Conscious||!belongs_to(w,id,actor->second.inventory)){weapon.trigger=false;abort_reload(w,weapon);continue;}
        auto& receiver=d.receivers.at(d.items.at(w.items.at(id).defId).partDefId);
        weapon.heatK=std::max(293.15,weapon.heatK-receiver.coolingPerS/60);weapon.recoilPitch*=.9;weapon.recoilYaw*=.9;
        if(weapon.phase!=WeaponPhase::Ready&&weapon.phase!=WeaponPhase::Idle&&weapon.phase!=WeaponPhase::Jammed&&s.tick>=weapon.nextPhaseTick)
            step_reload(d.items,w,weapon,receiver,s.tick,actor->second.inventory,ids.take(),event,d.ammunition);
        if(weapon.trigger&&weapon.phase==WeaponPhase::Ready&&(!weapon.shotCounter||s.tick>=weapon.lastFireTick+receiver.firePeriodTicks)) {
            if(!chamber_state(w,id).round){weapon.trigger=false;continue;}
            auto& control=s.controls.at(actor->first);GameCommand c;c.targets[0]=id;c.sequence=weapon.inputSeq+1;c.revision=weapon.assemblyRevision;c.yaw=control.yaw;c.pitch=control.pitch;
            perform_shot(d,w,s,c,{weapon.owner,actor->first,false,true},ids,event,true);
        }
    }
}
}
