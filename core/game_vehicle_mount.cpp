#include "game_execution.hpp"
#include "game_flags.hpp"
#include "mutation.hpp"
namespace astra {
void mount_vehicle_part(const GameDefinitions& d,World& w,GameState& s,Vehicle& v,const GameCommand& c,const GamePeer& peer){
    require(!v.driver&&length(v.velocity)<1&&c.revision==v.assemblyRevision&&c.definition>=1&&c.definition<=7&&w.items.contains(c.targets[1]),Error::NotAccessible);
    auto id=c.targets[1];auto& item=w.items.at(id);auto ordinal=c.definition;
    auto expected=ordinal==1?121u:ordinal==2?122u:ordinal<=6?119u:123u;
    require(item.defId==expected&&item.quantity==1&&item.durability&&!(item.flags&(leased_tool|deleted)),Error::Incompatible);
    auto bag=s.lives.at(peer.actor).inventory;auto ground=s.groundAssets.find(id);bool carried=belongs_to(w,id,bag);
    require(carried||(ground!=s.groundAssets.end()&&ground->second.item==id&&length(ground->second.position-s.lives.at(peer.actor).position)<=3),Error::NotAccessible);
    Id socket;for(auto& [cid,container]:w.containers)if(container.state.ownerItem==v.entity&&container.kind==PlaceKind::Socket)socket=cid;
    require(bool(socket)&&v.parts.size()<64,Error::InvalidState);
    for(auto& [other,p]:w.placements){(void)other;require(p.container!=socket||p.socketId!=ordinal,Error::InvalidPlacement);}
    auto& profile=d.parts.at(d.items.at(item.defId).partDefId);auto position=ordinal<=2?Vec3{.5,0,0}:ordinal<=6?d.wheels.at(ordinal-3).anchor:Vec3{0,0,.5};
    MassPart part{id,d.items.at(item.defId).massG/1000.0,position,profile.inertia};auto old=combine_mass(v.parts);
    auto rotation=transpose(v.rotation);auto velocity=transform(rotation,v.velocity),omega=transform(rotation,v.omega);
    auto pv=carried?Vec3{}:transform(rotation,ground->second.velocity),pw=carried?Vec3{}:transform(rotation,ground->second.omega);
    auto momentum=velocity*old.massKg+pv*part.massKg;
    auto angular=transform(old.inertia,omega)+cross(old.com,velocity*old.massKg)+transform(part.inertia,pw)+cross(part.com,pv*part.massKg);
    v.parts.push_back(part);auto mass=combine_mass(v.parts);v.velocity=transform(v.rotation,momentum/mass.massKg);v.omega=transform(v.rotation,transform(inverse(mass.inertia),angular-cross(mass.com,momentum)));
    w.placements.at(id)={id,socket,ordinal,0,0,0,PlaceKind::Socket};bump(item.revision);
    if(!carried)ground->second.item={};
    if(ordinal==1)v.torquePath=true;if(ordinal>=3&&ordinal<=6){v.wheels.at(ordinal-3).attached=true;v.drivenMask|=std::uint8_t(1u<<(ordinal-3));}
    ++v.assemblyRevision;s.drivingInputs.erase(v.entity);
}
}
