#include "world_simulation.hpp"
#include <span>
namespace astra {
unsigned cell_of(Vec3 p) {
    require(finite(p),Error::InvalidRequest);bounded(p.x,-2000,2000);bounded(p.y,-2000,2000);
    return std::min(31u,unsigned((p.x+2000)/125))+32*std::min(31u,unsigned((p.y+2000)/125));
}
std::array<bool,1024> active_cells(std::span<const Observer> observers) {
    require(observers.size()<=20,Error::LimitExceeded);std::array<bool,1024> result{};
    for(auto o:observers) {
        cell_of(o.position);auto radius=o.driving?600:300;
        for(unsigned y=0;y<32;++y)for(unsigned x=0;x<32;++x) {
            auto dx=o.position.x-std::clamp(o.position.x,x*125.0-2000,(x+1)*125.0-2000);
            auto dy=o.position.y-std::clamp(o.position.y,y*125.0-2000,(y+1)*125.0-2000);
            if(dx*dx+dy*dy<=radius*radius)result[x+32*y]=true;
        }
    }return result;
}
void pin(Cell& c,PinReason reason,int delta) {
    require(unsigned(reason)<c.pins.size(),Error::InvalidRequest);auto value=int(c.pins[unsigned(reason)])+delta;
    require(value>=0&&value<=UINT16_MAX,Error::InvalidState);c.pins[unsigned(reason)]=std::uint16_t(value);
}
bool can_unload(const Cell& c) {
    return std::all_of(c.pins.begin(),c.pins.end(),[](auto n){return n==0;})&&c.dirtyRevision==c.savedRevision;
}
double loading_distance(double v,double load,double safety,double brake) {
    bounded(v,0,120);bounded(load,0,60);bounded(safety,0,60);bounded(brake,.1,30);
    return v*(load+safety)+v*v/(2*brake);
}
bool line_of_sight(Vec3 a,Vec3 b,const std::map<Id,Structure>& structures,const std::map<std::uint32_t,StructureDef>& defs) {
    require(finite(a)&&finite(b),Error::InvalidRequest);
    for(const auto& [id,s]:structures) {
        (void)id;if(s.destroyed||s.open)continue;auto h=defs.at(s.definition).halfExtent;
        double lo=0,hi=1,from[]{a.x,a.y,a.z},to[]{b.x,b.y,b.z},center[]{s.position.x,s.position.y,s.position.z},half[]{h.x,h.y,h.z};
        bool intersects=true;
        for(unsigned i=0;i<3;++i) {
            auto d=to[i]-from[i];
            if(d==0){if(from[i]<center[i]-half[i]||from[i]>center[i]+half[i])intersects=false;continue;}
            auto x=(center[i]-half[i]-from[i])/d,y=(center[i]+half[i]-from[i])/d;if(x>y)std::swap(x,y);
            lo=std::max(lo,x);hi=std::min(hi,y);
        }
        if(intersects&&lo<=hi&&hi>.00001&&lo<.99999)return false;
    }return true;
}
}
