#include "weapons.hpp"
#include "mutation.hpp"
namespace astra {
WeaponStats weapon_stats(const Catalog& cat,const World& w,Id root,const std::map<std::uint32_t,PartProfile>& defs,bool functional) {
    require(w.items.contains(root)&&w.placements.contains(root),Error::NotAccessible);
    std::vector<MassPart> masses;WeaponStats result;std::map<Id,Vec3> positions{{root,{}}};std::vector<Id> order{root};std::uint64_t tags=0;
    for(std::size_t n=0;n<order.size();++n) {
        auto id=order[n];const auto& item=w.items.at(id);auto partId=cat.at(item.defId).partDefId;
        require(defs.contains(partId)&&order.size()<=32,Error::Incompatible);auto& part=defs.at(partId);tags|=part.tags;
        masses.push_back({id,cat.at(item.defId).massG/1000.0,positions.at(id)+part.com,part.inertia});
        result.ergonomics+=part.ergonomics;result.velocityScale*=part.velocityScale;result.dispersionRad+=part.dispersionRad*part.dispersionRad;
        result.recoilScale*=part.recoilScale;result.revisionHash^=id.hi+id.lo*31+item.revision*0x9e3779b97f4a7c15ULL;
        for(auto socket:part.sockets) {
            Id child{};
            for(const auto& [other,p]:w.placements)if(p.kind==PlaceKind::Socket&&w.containers.at(p.container).state.ownerItem==id&&p.socketId==socket.id){require(!child,Error::InvalidState);child=other;}
            if(socket.required&&functional)require(bool(child),Error::Incompatible);
            if(!child)continue;auto childDef=cat.at(w.items.at(child).defId).partDefId;
            require(defs.contains(childDef)&&defs.at(childDef).mountProfile==socket.profile&&!positions.contains(child),Error::Incompatible);
            positions[child]=positions.at(id)+socket.position;order.push_back(child);
        }
    }
    for(auto id:order){auto& p=defs.at(cat.at(w.items.at(id).defId).partDefId);require((!functional||(tags&p.requiredTags)==p.requiredTags)&&!(tags&p.forbiddenTags),Error::Incompatible);}
    std::vector<MassPart> carried;
    for(unsigned depth=0;depth<8;++depth)for(auto& [id,item]:w.items)if(!positions.contains(id)&&w.placements.contains(id)){
        auto owner=w.containers.at(w.placements.at(id).container).state.ownerItem;if(!positions.contains(owner))continue;
        auto mass=cat.at(item.defId).massG*double(item.quantity)/1000;require(mass>0,Error::InvalidState);
        auto position=positions.at(owner);if(owner==root)position=position+Vec3{0,0,-.12};positions[id]=position;
        auto inertia=std::max(1e-7,mass*.001);carried.push_back({id,mass,position,diagonal(inertia,inertia,inertia)});
        result.revisionHash^=id.lo*31+item.revision*0x9e3779b97f4a7c15ULL;
    }
    if(!carried.empty()){auto c=combine_mass(carried);masses.push_back({carried.front().item,c.massKg,c.com,c.inertia});}
    auto mass=combine_mass(masses);result.massKg=mass.massKg;result.com=mass.com;result.inertia=mass.inertia;
    result.ergonomics=std::clamp(result.ergonomics-mass.massKg*2-length(mass.com)*10,0.0,100.0);result.dispersionRad=std::sqrt(result.dispersionRad);
    return result;
}
void attach_part(const Catalog& cat,World& w,Id item,Id target,std::uint32_t ordinal,const std::map<std::uint32_t,PartProfile>& defs) {
    require(w.containers.contains(target)&&w.containers.at(target).kind==PlaceKind::Socket&&w.items.contains(item),Error::NotAccessible);
    auto parent=w.containers.at(target).state.ownerItem;
    auto& p=defs.at(cat.at(w.items.at(parent).defId).partDefId);auto childId=cat.at(w.items.at(item).defId).partDefId;
    auto s=std::find_if(p.sockets.begin(),p.sockets.end(),[&](auto& socket){return socket.id==ordinal;});
    require(s!=p.sockets.end()&&defs.contains(childId)&&s->profile==defs.at(childId).mountProfile,Error::Incompatible);
    w.placements.at(item)={item,target,ordinal,0,0,0,PlaceKind::Socket};bump(w.items.at(item).revision);bump(w.items.at(parent).revision);
}
}
