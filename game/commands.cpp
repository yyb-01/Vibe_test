#include "host.hpp"
namespace astra::native {
GameCommand command(std::istringstream& in,const GameState& s,const GamePeer& p,Id id,const std::optional<GameCommand>& old) {
    GameCommand c;c.id=id;c.lifeEpoch=old?old->lifeEpoch:(p.host?1:s.lives.at(p.actor).epoch);c.tick=old?old->tick:s.tick;
    auto item=[&](unsigned n){std::string text;require(bool(in>>text),Error::InvalidRequest);c.targets.at(n)=parse_id(text);};
    auto weapon=[&]{item(0);require(s.weapons.contains(c.targets[0]),Error::NotAccessible);auto& w=s.weapons.at(c.targets[0]);c.revision=old?old->revision:w.assemblyRevision;c.sequence=old?old->sequence:w.inputSeq+1;};
    std::string v;in>>v;
    if(v=="tick"){require(p.host,Error::NotAccessible);c.operation=GameOperation::Tick;c.tick=old?old->tick:s.tick+1;}
    else if(v=="online"){c.operation=GameOperation::Presence;in>>c.enabled;}
    else if(v=="move"){c.operation=GameOperation::Move;in>>c.position.x>>c.position.y>>c.position.z;}
    else if(v=="aim"){c.operation=GameOperation::Aim;in>>c.yaw>>c.pitch;}
    else if(v=="consume"){c.operation=GameOperation::Consume;item(0);}
    else if(v=="treat"){c.operation=GameOperation::Treat;item(0);item(1);in>>c.event;}
    else if(v=="respawn")c.operation=GameOperation::Respawn;
    else if(v=="equip"){c.operation=GameOperation::Equip;item(0);in>>c.enabled;}
    else if(v=="swap"){c.operation=GameOperation::InventorySwap;item(0);item(1);}
    else if(v=="drop"){c.operation=GameOperation::Drop;item(0);in>>c.quantity;}
    else if(v=="put"||v=="split"||v=="merge") {
        c.operation=v=="put"?GameOperation::InventoryMove:v=="split"?GameOperation::InventorySplit:GameOperation::InventoryMerge;
        item(0);item(1);in>>c.quantity>>c.position.x>>c.position.y>>c.definition;
    }
    else if(v=="fire"||v=="clear"||v=="reload"||v=="trigger") {
        weapon();c.operation=v=="fire"?GameOperation::Fire:v=="clear"?GameOperation::ClearJam:v=="reload"?GameOperation::Reload:GameOperation::Trigger;
        c.yaw=old?old->yaw:s.controls.at(p.actor).yaw;c.pitch=old?old->pitch:s.controls.at(p.actor).pitch;
        if(v=="reload")item(1);if(v=="trigger")in>>c.enabled;
    } else if(v=="attach"){c.operation=GameOperation::Attach;item(0);item(1);in>>c.definition;}
    else if(v=="detach"){c.operation=GameOperation::Detach;item(0);}
    else if(v=="craft"){c.operation=GameOperation::Craft;item(0);in>>c.definition>>c.quantity;}
    else if(v=="collect"||v=="cancel"){c.operation=v=="collect"?GameOperation::Collect:GameOperation::Cancel;item(0);}
    else if(v=="build"){c.operation=GameOperation::Build;in>>c.definition>>c.position.x>>c.position.y>>c.position.z;std::string support;if(in>>support){c.targets[0]=parse_id(support);if(!(in>>c.quantity))in.clear();}else in.clear();}
    else if(v=="destroy"||v=="door"||v=="trap"||v=="lock"){c.operation=v=="destroy"?GameOperation::Destroy:v=="door"?GameOperation::Door:v=="lock"?GameOperation::Lock:GameOperation::ArmTrap;item(0);if(v!="destroy")in>>c.enabled;}
    else if(v=="connect"){c.operation=GameOperation::ConnectPower;item(0);item(1);}
    else if(v=="refuel"){c.operation=GameOperation::Refuel;item(0);in>>c.quantity;}
    else if(v=="loot"){c.operation=GameOperation::Loot;item(0);in>>c.quantity;}
    else if(v=="enter"||v=="exit"||v=="drive"||v=="detachvehicle"||v=="attachvehicle") {
        item(0);require(s.vehicles.contains(c.targets[0]),Error::NotAccessible);c.revision=old?old->revision:s.vehicles.at(c.targets[0]).assemblyRevision;
        c.operation=v=="enter"?GameOperation::EnterVehicle:v=="exit"?GameOperation::ExitVehicle:v=="drive"?GameOperation::Drive:v=="attachvehicle"?GameOperation::AttachVehicle:GameOperation::DetachVehicle;
        if(v=="drive"){in>>c.throttle>>c.brake>>c.steer;int gear{};in>>gear;require(gear>=0&&gear<16,Error::InvalidRequest);c.gear=std::int8_t(gear);c.tick=old?old->tick:s.tick+1;c.sequence=old?old->sequence:s.drivingInputs.contains(c.targets[0])?s.drivingInputs.at(c.targets[0]).sequence+1:1;}
        if(v=="detachvehicle")item(1);
        if(v=="attachvehicle"){item(1);in>>c.definition;}
    } else throw Violation{Error::InvalidRequest};
    if(c.operation==GameOperation::Move||c.operation==GameOperation::Aim)c.sequence=old?old->sequence:s.controls.at(p.actor).inputSeq+1;
    require(!in.fail(),Error::InvalidRequest);std::string extra;require(!(in>>extra),Error::InvalidRequest);return c;
}
}
