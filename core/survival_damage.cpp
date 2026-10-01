#include "survival.hpp"
namespace astra {
void wound(Life& l,std::uint64_t event,Region region,double energy,bool blunt,bool vital) {
    validate_life(l);bounded(energy,0,100000);require(event&&unsigned(region)<8,Error::InvalidRequest);
    if(l.status==LifeStatus::Dead)return;
    for(const auto& w:l.wounds)if(w.event==event)return;
    double damage=std::min(100.0,energy*(blunt?.025:.1));
    auto& hp=l.health[unsigned(region)];hp=std::max(0.0,hp-damage);
    auto& slot=injury_slot(l,event,region);slot.arterialMlS=blunt?0:damage*.02;slot.venousMlS=blunt?0:damage*.04;slot.pain=damage;slot.fracture=blunt&&damage>25?damage:0;
    if(vital||((region==Region::Head||region==Region::Thorax)&&hp==0))l.status=LifeStatus::Dead;
    ++l.revision;
}
void treat_wound(Life& l,std::uint64_t event,double factor,bool stabilize) {
    bounded(factor,0,1);
    auto i=std::find_if(l.wounds.begin(),l.wounds.end(),[&](const Wound& w){return w.event==event;});
    require(i!=l.wounds.end()&&l.status!=LifeStatus::Dead,Error::InvalidRequest);
    i->treatment=std::min(i->treatment,factor);if(stabilize)i->fracture*=.5;++l.revision;
}
void ingest(Life& l,double ml,double kcal,const std::map<std::uint32_t,double>& doses,std::uint64_t seed) {
    bounded(ml,0,2000);bounded(kcal,0,4000);require(l.status==LifeStatus::Conscious,Error::NotAccessible);
    require(l.digestiveMl+ml<=3000&&l.digestiveKcal+kcal<=6000&&doses.size()<=16,Error::CapacityExceeded);
    for(auto [id,dose]:doses) { require(id,Error::InvalidRequest);bounded(dose,0,1e9); }
    for(auto [id,dose]:doses) {
        auto& p=l.pathogens[id];p.dose+=dose;
        auto random=seed^(std::uint64_t(id)*0x9e3779b97f4a7c15ULL);random^=random>>30;random*=0xbf58476d1ce4e5b9ULL;
        if(!p.infected&&double(random>>11)/9007199254740992.0<1-std::exp(-p.dose*.001)) {
            p.infected=true;p.onsetTick=l.tick+3600;
        }
    }
    l.digestiveMl+=ml;l.digestiveKcal+=kcal;++l.revision;
}
double armor_integrity(const ArmorMap& m,double u,double v) {
    bounded(u,0,1);bounded(v,0,1);return m.integrity[std::min(15u,unsigned(u*16))+16*std::min(15u,unsigned(v*16))]/255.0;
}
void damage_armor(ArmorMap& m,double u,double v,double energy,double radius) {
    armor_integrity(m,u,v);bounded(energy,0,1e6);bounded(radius,.00001,1);
    for(unsigned y=0;y<16;++y)for(unsigned x=0;x<16;++x) {
        auto r=std::hypot((x+.5)/16-u,(y+.5)/16-v);
        auto loss=std::min(255.0,energy*.1*std::max(0.0,1-r/radius));
        auto& q=m.integrity[x+y*16];q=std::uint8_t(std::max(0.0,q-loss));
    }
}
}
