#include "survival.hpp"
namespace astra {
void validate_life(const Life& l) {
    require(l.entity&&l.account&&l.inventory&&l.epoch&&l.revision&&unsigned(l.status)<=2&&finite(l.position),Error::InvalidState);
    for(auto v:{l.bloodMl,l.hydrationMl,l.energyKcal,l.staminaJ,l.fatigue,l.oxygenDebt,l.digestiveMl,l.digestiveKcal})bounded(v,0,1e9);
    bounded(l.coreK,200,400);bounded(l.skinK,200,400);require(l.wounds.size()<=64&&l.pathogens.size()<=16,Error::InvalidState);
    for(auto hp:l.health)bounded(hp,0,100);
    for(auto w:l.wounds){require(w.event&&unsigned(w.region)<8,Error::InvalidState);bounded(w.treatment,0,1);bounded(w.arterialMlS,0,1e9);bounded(w.venousMlS,0,1e9);bounded(w.pain,0,100);bounded(w.fracture,0,100);bounded(w.depositedJ,0,2000000);}
    for(auto [id,p]:l.pathogens){require(id,Error::InvalidState);bounded(p.dose,0,1e15);bounded(p.progress,0,1);}
}
void advance_life(Life& l,const Environment& e,std::uint64_t target) {
    validate_life(l);require(target>=l.tick&&target-l.tick<=216000,Error::InvalidRequest);
    bounded(e.airK,200,400);bounded(e.radiantK,200,400);bounded(e.windMS,0,120);bounded(e.wetness,0,1);
    bounded(e.insulation,.05,20);bounded(e.metabolicW,0,3000);bounded(e.workW,0,3000);bounded(e.movementW,0,3000);
    for(auto t=l.tick+1;t<=target&&l.status!=LifeStatus::Dead;++t) {
        if(t%6==0) {
            double bleed=0;for(auto w:l.wounds)bleed+=(w.arterialMlS+w.venousMlS)*w.treatment;
            l.bloodMl=std::clamp(l.bloodMl+(.01-bleed*std::min(1.0,l.bloodMl/5000))*.1,0.0,5000.0);
            auto recover=e.resting?120*std::min(1.0,l.energyKcal/1000):20;
            l.staminaJ=std::clamp(l.staminaJ+(recover-e.movementW)*.1,0.0,20000.0);
            if(l.bloodMl<1000)l.status=LifeStatus::Dead;
            else if(l.bloodMl<2000)l.status=LifeStatus::Unconscious;
            else if(l.bloodMl>2400)l.status=LifeStatus::Conscious;
        }
        if(t%60)continue;
        auto water=std::min(l.digestiveMl,10.0),food=std::min(l.digestiveKcal,2.0);
        l.digestiveMl-=water;l.digestiveKcal-=food;
        l.hydrationMl=std::clamp(l.hydrationMl+water-.025-e.movementW*.0001,0.0,5000.0);
        l.energyKcal=std::clamp(l.energyKcal+food-e.metabolicW/4184,0.0,6000.0);
        auto q=(l.coreK-l.skinK)*15/e.insulation;
        auto conv=(5+e.windMS*2)*(e.sheltered?.3:1)*(l.skinK-e.airK);
        auto rad=.95*5.670374419e-8*1.8*(std::pow(l.skinK,4)-std::pow(e.radiantK,4));
        l.coreK=std::clamp(l.coreK+(e.metabolicW-e.workW-q)/240000,200.0,400.0);
        l.skinK=std::clamp(l.skinK+(q-conv-rad-e.wetness*100)/15000,200.0,400.0);
        l.cold=l.cold?l.coreK<309:l.coreK<308;l.hot=l.hot?l.coreK>311:l.coreK>312;
        l.coldExposure+=l.cold?1:0;l.heatExposure+=l.hot?1:0;
        for(auto& [id,p]:l.pathogens){(void)id;if(p.infected&&t>=p.onsetTick)p.progress=std::min(1.0,p.progress+.0001);}
    }
    if(target!=l.tick)++l.revision;l.tick=target;
}
}
