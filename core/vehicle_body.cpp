#include "game_execution.hpp"
namespace astra {
void integrate_vehicle(Vehicle& v,const VehicleForces& forces,const MassProperties& mass) {
    constexpr double dt=1.0/60;v.velocity=v.velocity+(forces.force/mass.massKg+Vec3{0,0,-9.80665})*dt;
    auto center=v.position+transform(v.rotation,mass.com)+v.velocity*dt;
    auto inverseRotation=transpose(v.rotation);auto localOmega=transform(inverseRotation,v.omega),localTorque=transform(inverseRotation,forces.torque);
    localOmega=localOmega+transform(inverse(mass.inertia),localTorque-cross(localOmega,transform(mass.inertia,localOmega)))*dt;
    v.omega=transform(v.rotation,localOmega);
    auto angle=length(localOmega)*dt;
    if(angle>1e-12) {
        auto a=localOmega/length(localOmega);double axis[]{a.x,a.y,a.z};auto r=diagonal(1,1,1);auto cs=std::cos(angle),sn=std::sin(angle);
        for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)r[i][j]=(i==j?cs:0)+(1-cs)*axis[i]*axis[j];
        r[0][1]-=sn*a.z;r[1][0]+=sn*a.z;r[0][2]+=sn*a.y;r[2][0]-=sn*a.y;r[1][2]-=sn*a.x;r[2][1]+=sn*a.x;
        v.rotation=multiply(v.rotation,r);
    }
    v.position=center-transform(v.rotation,mass.com);
    // Native headless floor contact. UE supplies its own terrain/body solver at integration.
    if(v.position.z<.4){v.position.z=.4;v.velocity.z=std::max(0.0,v.velocity.z);}
    require(finite(v.position)&&finite(v.velocity)&&finite(v.omega),Error::InvalidState);
    // Headless world boundary stops the body; a normal boundary contact must not abort the whole tick.
    if(std::abs(v.position.x)>=1999.99){v.position.x=std::copysign(1999.99,v.position.x);v.velocity.x=0;}
    if(std::abs(v.position.y)>=1999.99){v.position.y=std::copysign(1999.99,v.position.y);v.velocity.y=0;}
}
void tick_vehicles(const GameDefinitions& d,GameState& s) {
    for(auto& [id,v]:s.vehicles) {
        auto input=s.drivingInputs.contains(id)?s.drivingInputs.at(id):DriveInput{};
        if(!v.driver||s.tick>input.tick+30){input.throttle=0;input.brake=1;input.steer=v.steer;input.gear=v.gear;}
        input.tick=s.tick;input.sequence=v.inputSeq+1;input.assemblyRevision=v.assemblyRevision;
        auto mass=combine_mass(v.parts);auto center=v.position+transform(v.rotation,mass.com);
        std::vector<WheelContact> contacts(d.wheels.size());
        for(unsigned i=0;i<contacts.size();++i) {
            auto anchor=v.position+transform(v.rotation,d.wheels[i].anchor);
            auto velocity=v.velocity+cross(v.omega,anchor-center);
            auto& c=contacts[i];c.hit=anchor.z<=d.wheels[i].restLength+d.wheels[i].radius&&v.wheels[i].attached;c.distance=std::max(0.0,anchor.z);
            auto steer=Vec3{std::cos(v.steer*.6),std::sin(v.steer*.6),0};c.forward=transform(v.rotation,steer);c.forward.z=0;
            if(length(c.forward)<.1)c.forward={1,0,0};else c.forward=c.forward/length(c.forward);
            c.forwardSpeed=dot(velocity,c.forward);c.sideSpeed=dot(velocity,cross(c.normal,c.forward));
        }
        auto owner=v.driver?v.driver:simulation_account;auto savedDriver=v.driver;v.driver=owner;
        auto forces=drive(v,d.engine,d.wheels,contacts,input,owner);v.driver=savedDriver;
        integrate_vehicle(v,forces,mass);
        for(auto& [actor,control]:s.controls)if(control.vehicle==id)s.lives.at(actor).position=v.position;
    }
}
}
