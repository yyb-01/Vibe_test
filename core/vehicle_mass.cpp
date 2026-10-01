#include "vehicle.hpp"
namespace astra {
static Mat3 shift(double mass,Vec3 v) {
    double a[]{v.x,v.y,v.z};Mat3 r{};
    for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)r[i][j]=mass*((i==j?dot(v,v):0)-a[i]*a[j]);
    return r;
}
MassProperties combine_mass(std::vector<MassPart> parts) {
    require(!parts.empty()&&parts.size()<=64,Error::InvalidState);
    std::sort(parts.begin(),parts.end(),[](auto& a,auto& b){return a.item<b.item;});
    MassProperties result;Mat3 origin{};Vec3 moment{};Id previous{};
    for(auto& p:parts) {
        require(p.item&&previous<p.item&&finite(p.com),Error::InvalidState);previous=p.item;bounded(p.massKg,.000001,1e6);
        principal_axes(p.inertia);auto orth=multiply(p.rotation,transpose(p.rotation));
        for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)bounded(orth[i][j]-(i==j?1:0),-1e-6,1e-6);
        auto oriented=multiply(p.rotation,multiply(p.inertia,transpose(p.rotation))),s=shift(p.massKg,p.com);
        result.massKg+=p.massKg;moment=moment+p.com*p.massKg;
        for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)origin[i][j]+=oriented[i][j]+s[i][j];
    }
    result.com=moment/result.massKg;auto s=shift(result.massKg,result.com);
    for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)result.inertia[i][j]=origin[i][j]-s[i][j];
    principal_axes(result.inertia);return result;
}
DetachedMotion detach_part(const std::vector<MassPart>& parts,Id item,Vec3 v,Vec3 omega) {
    require(finite(v)&&finite(omega),Error::InvalidRequest);
    auto old=combine_mass(parts);auto remaining=parts;
    auto found=std::find_if(remaining.begin(),remaining.end(),[&](auto& p){return p.item==item;});
    require(found!=remaining.end()&&remaining.size()>1,Error::InvalidRequest);auto part=*found;remaining.erase(found);
    auto next=combine_mass(remaining);auto partV=v+cross(omega,part.com-old.com);
    auto oldP=v*old.massKg,partP=partV*part.massKg,newP=oldP-partP;
    auto oldL=transform(old.inertia,omega)+cross(old.com,oldP);
    auto partI=multiply(part.rotation,multiply(part.inertia,transpose(part.rotation)));
    auto partL=transform(partI,omega)+cross(part.com,partP);
    return {newP/next.massKg,transform(inverse(next.inertia),oldL-partL-cross(next.com,newP)),partV,omega,next};
}
}
