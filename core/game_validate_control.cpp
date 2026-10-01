#include "game_state.hpp"
#include <set>
namespace astra {
void validate_controls(const GameState& s){
    require(s.controls.size()==s.lives.size()&&s.groundAssets.size()<=10000&&s.history.size()<=31,Error::InvalidState);
    for(auto& [id,c]:s.controls){
        require(s.lives.contains(id)&&c.moveTick<=s.tick&&c.aimTick<=s.tick&&c.disconnectTick<=s.tick&&(!c.connected||c.everJoined),Error::InvalidState);
        if(c.weapon)require(s.weapons.contains(c.weapon)&&s.weapons.at(c.weapon).owner==s.lives.at(id).account,Error::InvalidState);
        if(c.armor)require(s.armor.contains(c.armor),Error::InvalidState);
        if(c.vehicle)require(s.vehicles.contains(c.vehicle)&&s.vehicles.at(c.vehicle).driver==s.lives.at(id).account,Error::InvalidState);
    }
    for(auto& [id,v]:s.vehicles)if(v.driver){
        bool found=false;for(auto& [actor,l]:s.lives)if(l.account==v.driver&&s.controls.at(actor).vehicle==id)found=true;
        require(found,Error::InvalidState);
    }
    for(auto& [id,g]:s.groundAssets){
        require(id&&finite(g.position)&&finite(g.velocity)&&finite(g.omega)&&(!g.spawnDef||g.quantity)&&g.quantity<=1000,Error::InvalidState);cell_of(g.position);
    }
    for(auto& [id,input]:s.drivingInputs){
        require(s.vehicles.contains(id)&&input.sequence&&input.assemblyRevision==s.vehicles.at(id).assemblyRevision&&input.tick<=s.tick+1,Error::InvalidState);
        bounded(input.throttle,-1,1);bounded(input.brake,0,1);bounded(input.steer,-1,1);require(input.gear>=0&&input.gear<16,Error::InvalidState);
    }
    std::uint64_t previous=0;bool first=true;
    for(auto& frame:s.history){
        require((first||frame.tick>previous)&&frame.tick<=s.tick&&frame.actors.size()<=840&&frame.doors.size()<=512,Error::InvalidState);
        previous=frame.tick;first=false;std::set<Id> actors,doors;
        for(auto& a:frame.actors)require(a.entity&&a.epoch&&a.kind<=2&&finite(a.position)&&actors.insert(a.entity).second&&(!a.armor||a.armor->item),Error::InvalidState);
        for(auto& door:frame.doors)require(door.entity&&doors.insert(door.entity).second,Error::InvalidState);
    }
}
}
