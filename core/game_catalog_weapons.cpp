#include "game_state.hpp"
namespace astra {
void weapon_definitions(GameDefinitions& d) {
    for(unsigned id=1;id<=11;++id){PartProfile p;p.id=id;p.inertia=diagonal(.02,.04,.04);d.parts.emplace(id,p);}
    auto& receiver=d.parts.at(1);receiver.sockets={{1,10,{.25,0,0},true},{2,11,{0,0,.15},false}};receiver.ergonomics=75;
    auto& barrel=d.parts.at(2);barrel.mountProfile=10;barrel.sockets={{1,12,{.35,0,0},false}};barrel.halfExtent={.2,.025,.025};
    d.parts.at(3).mountProfile=12;d.parts.at(3).halfExtent={.1,.03,.03};d.parts.at(3).velocityScale=.98;
    d.parts.at(4).mountProfile=11;d.parts.at(4).dispersionRad=.0001;
    d.parts.at(6).halfExtent={.15,.2,.025};d.parts.at(7).inertia=diagonal(400,1000,1000);
    d.parts.at(8).inertia=diagonal(2,2,2);d.parts.at(9).inertia=diagonal(10,10,10);
    d.parts.at(10).inertia=diagonal(1,1,1);d.parts.at(11).inertia=diagonal(1,1,1);
    ReceiverProfile rifle;rifle.id=1;rifle.family=1;rifle.chamberProfile=1;rifle.automatic=true;d.receivers.emplace(1,rifle);
    AmmoProfile ball;ball.id=105;ball.family=1;ball.chamberProfile=1;d.ammunition.emplace(ball.id,ball);
    auto ap=ball;ap.id=106;ap.massMg=10000;ap.speedUmS=800000000;d.ammunition.emplace(ap.id,ap);
}
}
