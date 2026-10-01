#include "vehicle.hpp"
namespace astra {
VehicleForces drive(Vehicle& v,const EngineDef& d,std::span<const WheelDef> defs,std::span<const WheelContact> contacts,const DriveInput& in,Id account) {
    require(account&&account==v.driver&&in.assemblyRevision==v.assemblyRevision,Error::NotAccessible);
    require(in.tick==v.tick+1&&std::int32_t(in.sequence-v.inputSeq)>0&&defs.size()==v.wheels.size()&&contacts.size()==defs.size()&&defs.size()<=6,Error::InvalidRequest);
    bounded(in.throttle,-1,1);bounded(in.brake,0,1);bounded(in.steer,-1,1);
    require(in.gear>=0&&std::size_t(in.gear)<d.gears.size()&&d.torqueCurve.size()>=2,Error::InvalidRequest);
    bounded(in.steer-v.steer,-.1,.1);bounded(d.inertia,.01,10);bounded(d.efficiency,.01,1);
    double torque=0,previous=-1;
    for(auto [rpm,nm]:d.torqueCurve){bounded(rpm,0,30000);bounded(nm,0,10000);require(rpm>previous,Error::InvalidState);previous=rpm;}
    for(std::size_t i=1;i<d.torqueCurve.size();++i) {
        auto [x,a]=d.torqueCurve[i-1];auto [y,b]=d.torqueCurve[i];
        if(v.engineRpm>=x&&v.engineRpm<=y){torque=a+(b-a)*(v.engineRpm-x)/(y-x);break;}
    }
    double wheelOmega=0;unsigned driven=0;
    for(unsigned i=0;i<v.wheels.size();++i)if(v.drivenMask&(1u<<i)){wheelOmega+=v.wheels[i].omega;++driven;}
    auto ratio=d.gears[in.gear]*d.finalRatio;
    auto target=driven?std::abs(wheelOmega/driven*ratio)*60/(2*3.141592653589793):d.idleRpm;
    auto clutch=std::clamp((v.engineRpm-target)*.1,-d.clutchNm,d.clutchNm)*v.clutch;
    if(!v.running||!v.fuelUl||!v.torquePath||(in.throttle==0&&target<=d.idleRpm))clutch=0;
    auto engineTorque=v.running&&v.fuelUl&&v.torquePath?torque*std::abs(in.throttle):0;
    v.engineRpm=std::clamp(v.engineRpm+(engineTorque-clutch)*60/(2*3.141592653589793*d.inertia*60),v.running&&v.fuelUl?d.idleRpm:0.0,d.redlineRpm);
    auto total=v.running&&v.fuelUl&&v.torquePath?clutch*ratio*d.efficiency:0;
    VehicleForces result;auto mass=combine_mass(v.parts);
    for(unsigned i=0;i<v.wheels.size();++i) {
        auto force=wheel_force(v.wheels[i],defs[i],contacts[i],driven&&(v.drivenMask&(1u<<i))?total/driven:0,in.brake*3000,1.0/60);
        result.force=result.force+force.force;result.torque=result.torque+cross(transform(v.rotation,force.point-mass.com),force.force);result.wheels.push_back(force);
    }
    v.fuelResidual+=v.running?(50+std::abs(engineTorque)*.5)/60:0;
    auto fuel=std::uint64_t(v.fuelResidual);fuel=std::min(fuel,v.fuelUl);v.fuelUl-=fuel;v.fuelResidual-=fuel;
    if(!v.fuelUl)v.running=false;
    v.tick=in.tick;v.inputSeq=in.sequence;v.gear=in.gear;v.steer=in.steer;++v.revision;return result;
}
}
