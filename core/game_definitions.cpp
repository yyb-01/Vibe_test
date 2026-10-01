#include "game_state.hpp"
namespace astra {
void validate_catalog(const Catalog&);
void validate_definitions(const GameDefinitions& d) {
    require(d.version,Error::InvalidState);validate_catalog(d.items);validate_recipes(d.items,d.recipes);
    for(auto& [id,p]:d.parts) {
        require(id&&id==p.id&&p.sockets.size()<=32&&finite(p.com)&&finite(p.halfExtent),Error::InvalidState);principal_axes(p.inertia);
        bounded(p.halfExtent.x,.0001,10);bounded(p.halfExtent.y,.0001,10);bounded(p.halfExtent.z,.0001,10);
        bounded(p.ergonomics,-100,100);bounded(p.velocityScale,.1,10);bounded(p.dispersionRad,0,1);bounded(p.recoilScale,.1,10);
        std::set<std::uint32_t> sockets;for(auto& socket:p.sockets)require(socket.id&&socket.profile&&finite(socket.position)&&sockets.insert(socket.id).second,Error::InvalidState);
    }
    for(auto& [id,a]:d.ammunition) {
        require(id==a.id&&d.items.contains(id)&&a.family&&a.chamberProfile&&a.massMg>0&&a.massMg<=1000000&&a.speedUmS>0&&a.speedUmS<=2000000000&&
            a.radiusUm>=0&&a.radiusUm<=100000&&a.soundSpeedUmS&&a.dragMach.size()>=2&&a.dragMach.size()<=256,Error::InvalidState);
        std::uint32_t previous=0;bool first=true;
        for(auto [mach,drag]:a.dragMach){require((first||mach>previous)&&drag<=10000,Error::InvalidState);first=false;previous=mach;}
    }
    for(auto& [id,r]:d.receivers) {
        require(id==r.id&&d.parts.contains(id)&&r.family&&r.chamberProfile&&r.firePeriodTicks&&r.reloadStepTicks,Error::InvalidState);
        bounded(r.heatPerShotK,0,100);bounded(r.coolingPerS,0,100);bounded(r.baseJamProbability,0,1);
    }
    for(auto& [id,b]:d.structures) {
        require(id&&id==b.id&&unsigned(b.kind)<=7&&finite(b.halfExtent)&&b.massG&&b.capacityG&&b.health&&b.materials.size()<=32,Error::InvalidState);
        bounded(b.halfExtent.x,.01,20);bounded(b.halfExtent.y,.01,20);bounded(b.halfExtent.z,.01,20);bounded(b.maxSpanM,.01,30);bounded(b.maxSlopeRad,0,1.5);
        for(auto [def,n]:b.materials)require(d.items.contains(def)&&n,Error::InvalidState);
    }
    for(auto& [id,f]:d.foods){require(d.items.contains(id)&&f.pathogens.size()<=16,Error::InvalidState);bounded(f.waterMl,0,2000);bounded(f.energyKcal,0,4000);for(auto [pathogen,dose]:f.pathogens){require(pathogen,Error::InvalidState);bounded(dose,0,1e9);}}
}
}
