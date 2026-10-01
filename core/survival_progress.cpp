#include "survival.hpp"
namespace astra {
void wound_progress(Life& l,std::uint64_t event,Region region,double total,bool vital,double previous) {
    require(event&&unsigned(region)<8,Error::InvalidState);bounded(total,0,2000000);
    if(l.status==LifeStatus::Dead)return;
    require(previous==-1||(std::isfinite(previous)&&previous>=0&&previous<=total),Error::InvalidState);
    auto found=&injury_slot(l,event,region,std::max(0.0,previous));
    require(found->region==region&&total>=found->depositedJ,Error::InvalidState);
    auto damage=std::min(100.0,total*.1)-std::min(100.0,found->depositedJ*.1);
    l.health[unsigned(region)]=std::max(0.0,l.health[unsigned(region)]-damage);found->pain=std::min(100.0,found->pain+damage);
    found->arterialMlS+=damage*.02;found->venousMlS+=damage*.04;found->depositedJ=total;
    if(vital||((region==Region::Head||region==Region::Thorax)&&l.health[unsigned(region)]==0))l.status=LifeStatus::Dead;
    ++l.revision;
}
}
