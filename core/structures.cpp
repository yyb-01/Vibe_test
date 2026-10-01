#include "structures.hpp"
#include <set>
namespace astra {
Vec3 normalize_build(Vec3 p) {
    require(finite(p),Error::InvalidRequest);bounded(p.x,-2000,2000);bounded(p.y,-2000,2000);bounded(p.z,-100,1000);
    return {std::round(p.x*100)/100,std::round(p.y*100)/100,std::round(p.z*100)/100};
}
void validate_build(const Structure& s,const StructureDef& d,const std::map<Id,Structure>& world,const std::map<std::uint32_t,StructureDef>& defs,const BuildObservation& o) {
    require(s.entity&&s.owner&&s.definition==d.id&&s.position==normalize_build(s.position)&&s.supports.size()<=8,Error::InvalidPlacement);
    require(o.allowed&&o.lineOfSight&&o.terrainClear&&o.navigationClear&&finite(o.player)&&length(s.position-o.player)<=5,Error::NotAccessible);
    bounded(o.slopeRad,0,d.maxSlopeRad);
    if(d.kind==StructureKind::Foundation)require(std::abs(s.position.z-d.halfExtent.z-o.groundZ)<=.03&&s.supports.empty(),Error::InvalidPlacement);
    else require(!s.supports.empty(),Error::InvalidPlacement);
    for(const auto& [id,other]:world) {
        (void)id;if(other.destroyed)continue;auto bounds=defs.at(other.definition).halfExtent+d.halfExtent,delta=s.position-other.position;
        require(std::abs(delta.x)>=bounds.x-.001||std::abs(delta.y)>=bounds.y-.001||std::abs(delta.z)>=bounds.z-.001,Error::InvalidPlacement);
    }
    std::uint32_t sum=0;std::set<Id> seen;
    for(auto edge:s.supports) {
        require(world.contains(edge.parent)&&!world.at(edge.parent).destroyed&&seen.insert(edge.parent).second&&edge.share,Error::InvalidPlacement);
        const auto& parent=world.at(edge.parent);
        require(parent.position.z<s.position.z||(parent.position.z==s.position.z&&parent.entity<s.entity),Error::CycleDetected);
        require(length(parent.position-s.position)<=d.maxSpanM,Error::InvalidPlacement);sum+=edge.share;
    }
    require(s.supports.empty()||sum==65535,Error::InvalidState);
}
std::vector<Id> unsupported(const std::map<Id,Structure>& structures,const std::map<std::uint32_t,StructureDef>& defs) {
    std::vector<Id> order,failed;std::map<Id,std::uint64_t> loads;std::set<Id> invalid;
    for(auto& [id,s]:structures)if(!s.destroyed){order.push_back(id);auto& d=defs.at(s.definition);loads[id]=d.massG+d.maxCargoG;}
    std::sort(order.begin(),order.end(),[&](Id a,Id b){auto za=structures.at(a).position.z,zb=structures.at(b).position.z;return za!=zb?za>zb:a>b;});
    for(auto id:order) {
        auto& s=structures.at(id);auto& d=defs.at(s.definition);
        bool valid=d.kind==StructureKind::Foundation;
        if(loads[id]>d.capacityG)invalid.insert(id);
        std::uint64_t remaining=loads[id];
        for(std::size_t n=0;n<s.supports.size();++n) {
            auto edge=s.supports[n];if(!structures.contains(edge.parent)||structures.at(edge.parent).destroyed)continue;valid=true;
            auto load=n+1==s.supports.size()?remaining:loads[id]*edge.share/65535;remaining-=load;
            if(load>edge.capacityG)invalid.insert(id);loads[edge.parent]+=load;
        }
        if(!valid)invalid.insert(id);
    }
    std::reverse(order.begin(),order.end());
    for(auto id:order){auto& s=structures.at(id);for(auto edge:s.supports)if(invalid.contains(edge.parent))invalid.insert(id);}
    failed.assign(invalid.begin(),invalid.end());return failed;
}
bool shelter(Vec3 p,const std::map<Id,Structure>& structures,const std::map<std::uint32_t,StructureDef>& defs) {
    for(auto& [id,s]:structures){(void)id;auto& d=defs.at(s.definition);auto v=p-s.position;
        if(!s.destroyed&&d.kind==StructureKind::Roof&&v.z<0&&std::abs(v.x)<=d.halfExtent.x&&std::abs(v.y)<=d.halfExtent.y)return true;
    }return false;
}
}
