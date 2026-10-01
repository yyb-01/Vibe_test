#include "host.hpp"
#include "snapshot.hpp"
#include "game_execution.hpp"
#include <iomanip>
namespace astra::native {
std::string Host::view(unsigned slot) const {
    auto s=game->state();auto& l=s.lives.at({5,999+slot});auto w=inventory->snapshot();
    std::ostringstream out;out<<std::setprecision(12)<<"{\"code\":0,\"epoch\":"<<inventory->epoch()<<",\"tick\":"<<s.tick<<",\"lifeEpoch\":"<<l.epoch<<",\"actor\":\""<<id_text(l.entity)<<"\",\"bag\":\""<<id_text(l.inventory)<<"\",\"position\":["<<l.position.x<<','<<l.position.y<<','<<l.position.z<<"],\"bloodMl\":"<<l.bloodMl<<",\"waterMl\":"<<l.hydrationMl<<",\"energyKcal\":"<<l.energyKcal<<",\"staminaJ\":"<<l.staminaJ<<",\"coreK\":"<<l.coreK<<",\"status\":"<<unsigned(l.status)<<",\"items\":[";
    bool comma=false;
    auto item_json=[&](Id id){auto& item=w->items.at(id);auto& p=w->placements.at(id);
        out<<"{\"id\":\""<<id_text(id)<<"\",\"def\":"<<item.defId<<",\"qty\":"<<item.quantity<<",\"durability\":"<<item.durability<<",\"revision\":"<<item.revision<<",\"container\":\""<<id_text(p.container)<<"\",\"socket\":"<<p.socketId<<",\"x\":"<<p.x<<",\"y\":"<<p.y<<",\"rotation\":"<<unsigned(p.rotation)<<'}';};
    for(auto& [id,item]:w->items)if(w->placements.contains(id)&&ancestry(*w,w->placements.at(id).container).back()==l.inventory) {
        (void)item;if(comma)out<<',';comma=true;item_json(id);
    }
    auto& control=s.controls.at(l.entity);
    out<<"],\"yaw\":"<<control.yaw<<",\"pitch\":"<<control.pitch<<",\"weapons\":[";comma=false;
    for(auto& [id,weapon]:s.weapons)if(weapon.owner==l.account){
        if(comma)out<<',';comma=true;out<<"{\"id\":\""<<id_text(id)<<"\",\"revision\":"<<weapon.assemblyRevision<<",\"inputSeq\":"<<weapon.inputSeq<<",\"fireSeq\":"<<weapon.fireSeq<<",\"phase\":"<<unsigned(weapon.phase)<<",\"shots\":"<<weapon.shotCounter<<",\"effectiveQ16\":"<<weapon.lastEffectiveQ16<<'}';
    }
    out<<"],\"vehicle\":\""<<id_text(control.vehicle)<<"\",\"weapon\":\""<<id_text(control.weapon)<<"\",\"armor\":\""<<id_text(control.armor)<<"\",\"stores\":[";comma=false;
    for(auto& [id,station]:s.crafting.stations)if(accessible_container(definitions,*w,s,l.entity,station.output)){
        if(comma)out<<',';comma=true;out<<"{\"entity\":\""<<id_text(id)<<"\",\"container\":\""<<id_text(station.output)<<"\",\"items\":[";bool row=false;
        for(auto& [item,p]:w->placements)if(p.container==station.output){if(row)out<<',';row=true;item_json(item);}out<<"]}";
    }
    out<<"],\"jobs\":[";comma=false;
    for(auto& [id,j]:s.crafting.jobs)if(j.owner==l.account){if(comma)out<<',';comma=true;out<<"{\"id\":\""<<id_text(id)<<"\",\"recipe\":"<<j.recipe<<",\"phase\":"<<unsigned(j.phase)<<",\"progressUs\":"<<j.progressUs<<'}';}
    out<<"],\"nearby\":[";comma=false;
    auto entity=[&](Id id,const char* kind,Vec3 pos){if(length(pos-l.position)>300)return;if(comma)out<<',';comma=true;out<<"{\"id\":\""<<id_text(id)<<"\",\"kind\":\""<<kind<<"\",\"position\":["<<pos.x<<','<<pos.y<<','<<pos.z<<"]";
        if(s.structures.contains(id)){auto& b=s.structures.at(id);out<<",\"definition\":"<<b.definition<<",\"locked\":"<<(b.locked?"true":"false")<<",\"owned\":"<<(b.owner==l.account?"true":"false");}
        if(s.crafting.stations.contains(id)){auto& b=s.crafting.stations.at(id);out<<",\"capabilities\":"<<b.capabilities<<",\"output\":\""<<id_text(b.output)<<"\",\"power\":\""<<id_text(b.powerNode)<<'"';}
        out<<'}';};
    for(auto& [id,z]:s.world.zombies)if(z.health)entity(id,"zombie",z.position);
    for(auto& [id,v]:s.vehicles)entity(id,"vehicle",v.position);
    for(auto& [id,b]:s.structures)if(!b.destroyed&&!s.crafting.stations.contains(id))entity(id,"structure",b.position);
    for(auto& [id,b]:s.crafting.stations)entity(id,b.destroyed?"wreck":"station",b.position);
    for(auto& [id,g]:s.groundAssets)if(g.item)entity(g.item,"loot",g.position);
    for(auto& [id,other]:s.lives)if(id!=l.entity&&other.status!=LifeStatus::Dead&&active_player(s.controls.at(id),s.tick))entity(id,"player",other.position);
    out<<"],\"wounds\":[";comma=false;for(auto& wound:l.wounds){if(comma)out<<',';comma=true;out<<"{\"event\":\""<<wound.event<<"\",\"region\":"<<unsigned(wound.region)<<",\"bleedMlS\":"<<(wound.arterialMlS+wound.venousMlS)*wound.treatment<<'}';}
    out<<"]}";return out.str();
}
}
