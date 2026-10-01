#include "survival.hpp"
namespace astra {
Wound& injury_slot(Life& l,std::uint64_t event,Region region,double previous){
    for(auto& w:l.wounds)if(w.event==event){require(w.region==region,Error::InvalidState);return w;}
    // ponytail: retain 64 injury details; fold older same-region injuries while
    // preserving bleed. The projectile ledger supplies prior energy after folding.
    if(l.wounds.size()==64){
        std::array<unsigned,8> first;first.fill(64);
        for(unsigned i=0;i<64;++i){
            auto region=unsigned(l.wounds[i].region);require(region<8,Error::InvalidState);if(first[region]==64){first[region]=i;continue;}
            auto& a=l.wounds[first[region]];auto& b=l.wounds[i];
            a.arterialMlS=a.arterialMlS*a.treatment+b.arterialMlS*b.treatment;
            a.venousMlS=a.venousMlS*a.treatment+b.venousMlS*b.treatment;a.treatment=1;
            a.pain=std::min(100.0,a.pain+b.pain);a.fracture=std::max(a.fracture,b.fracture);
            l.wounds.erase(l.wounds.begin()+i);break;
        }
    }
    require(l.wounds.size()<64,Error::InvalidState);Wound w;w.event=event;w.region=region;w.depositedJ=previous;
    l.wounds.push_back(w);return l.wounds.back();
}
}
