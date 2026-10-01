#include "game_execution.hpp"
#include "packet.hpp"
#include "mutation.hpp"
namespace astra {
void mount_vehicle_part(const GameDefinitions&,World&,GameState&,Vehicle&,const GameCommand&,const GamePeer&);
bool vehicle_action(const GameDefinitions& d,World& w,GameState& s,const GameCommand& c,const GamePeer& p,GameIds&,std::uint64_t) {
    if(c.operation!=GameOperation::EnterVehicle&&c.operation!=GameOperation::ExitVehicle&&c.operation!=GameOperation::Drive&&c.operation!=GameOperation::DetachVehicle&&c.operation!=GameOperation::AttachVehicle)return false;
    auto& l=s.lives.at(p.actor);auto& control=s.controls.at(p.actor);
    require(s.vehicles.contains(c.targets[0]),Error::NotAccessible);auto& v=s.vehicles.at(c.targets[0]);
    require(length(l.position-v.position)<=3,Error::NotAccessible);
    if(c.operation==GameOperation::EnterVehicle){require(!v.driver&&!control.vehicle,Error::Busy);v.driver=p.account;control.vehicle=v.entity;if(v.torquePath&&v.fuelUl&&v.batteryMilliJ>=500000){if(!v.running)v.batteryMilliJ-=500000;v.running=true;}}
    else if(c.operation==GameOperation::ExitVehicle){require(v.driver==p.account&&length(v.velocity)<1,Error::NotAccessible);v.driver={};control.vehicle={};l.position=v.position+Vec3{0,1,0};l.position.z=0;}
    else if(c.operation==GameOperation::Drive) {
        require(v.driver==p.account&&c.revision==v.assemblyRevision&&c.tick==s.tick+1&&serial_newer(c.sequence,s.drivingInputs[v.entity].sequence),Error::NotAccessible);
        auto& input=s.drivingInputs[v.entity];require(std::abs(c.steer-input.steer)<=.1&&std::size_t(c.gear)<d.engine.gears.size(),Error::InvalidRequest);
        input={c.sequence,c.tick,c.revision,c.throttle,c.brake,c.steer,c.gear};return true;
    } else if(c.operation==GameOperation::AttachVehicle){mount_vehicle_part(d,w,s,v,c,p);}
    else {
        require(!v.driver&&length(v.velocity)<1&&c.revision==v.assemblyRevision&&c.targets[1]!=v.entity,Error::NotAccessible);
        auto found=std::find_if(v.parts.begin(),v.parts.end(),[&](auto& part){return part.item==c.targets[1];});require(found!=v.parts.end(),Error::NotAccessible);
        auto part=*found;auto rotation=transpose(v.rotation);auto motion=detach_part(v.parts,part.item,transform(rotation,v.velocity),transform(rotation,v.omega));
        v.velocity=transform(v.rotation,motion.chassisVelocity);v.omega=transform(v.rotation,motion.chassisOmega);v.parts.erase(found);
        auto def=w.items.at(part.item).defId;if(def==121){v.torquePath=false;v.running=false;}
        if(def==119){auto placement=w.placements.at(part.item);auto index=placement.socketId-3;require(index<v.wheels.size(),Error::InvalidState);v.wheels[index].attached=false;v.drivenMask&=std::uint8_t(~(1u<<index));}
        place_item(d.items,w,part.item,ground_root);bump(w.items.at(part.item).revision);
        s.groundAssets.emplace(part.item,GroundAsset{part.item,{},v.position+transform(v.rotation,part.com),transform(v.rotation,motion.partVelocity),transform(v.rotation,motion.partOmega)});
        ++v.assemblyRevision;s.drivingInputs.erase(v.entity);
    }
    ++v.revision;return true;
}
}
