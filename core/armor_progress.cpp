#include "survival.hpp"
namespace astra {
void damage_armor_progress(ArmorMap& m,double u,double v,double total,double previous,double radius){
    armor_integrity(m,u,v);bounded(total,0,2000000);bounded(previous,0,total);bounded(radius,.00001,1);
    for(unsigned y=0;y<16;++y)for(unsigned x=0;x<16;++x){
        auto r=std::hypot((x+.5)/16-u,(y+.5)/16-v),weight=.1*std::max(0.0,1-r/radius);
        auto loss=std::min(255.0,std::floor(total*weight))-std::min(255.0,std::floor(previous*weight));
        auto& q=m.integrity[x+y*16];q=std::uint8_t(std::max(0.0,q-loss));
    }
}
}
