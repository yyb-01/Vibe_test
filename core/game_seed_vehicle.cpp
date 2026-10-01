#include "game_command.hpp"
namespace astra {
void seed_vehicle(const GameDefinitions& d,World& w,GameState& s) {
    Vehicle v;v.entity={5,6000};v.position={5,0,.67};v.wheels.resize(4);v.running=true;
    ItemState chassis;chassis.id=v.entity;chassis.defId=118;w.items.emplace(chassis.id,chassis);place_item(d.items,w,chassis.id,ground_root);
    Container sockets;sockets.state.id={5,6001};sockets.state.ownerItem=chassis.id;sockets.state.width=32;sockets.state.height=1;sockets.state.capacityMl=UINT32_MAX;sockets.kind=PlaceKind::Socket;w.containers.emplace(sockets.state.id,sockets);
    v.parts.push_back({chassis.id,900,{},diagonal(400,1000,1000)});
    for(unsigned i=0;i<6;++i) {
        ItemState part;part.id={5,6010+i};part.defId=i==0?121:i==1?122:119;w.items.emplace(part.id,part);
        w.placements.emplace(part.id,Placement{part.id,sockets.state.id,i+1,0,0,0,PlaceKind::Socket});
        auto position=i<2?Vec3{.5,0,0}:d.wheels.at(i-2).anchor;
        v.parts.push_back({part.id,d.items.at(part.defId).massG/1000.0,position,d.parts.at(d.items.at(part.defId).partDefId).inertia});
    }
    s.vehicles.emplace(v.entity,v);
}
}
