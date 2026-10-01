#include "vehicle.hpp"
namespace astra {
WheelForce wheel_force(Wheel& w,const WheelDef& d,const WheelContact& c,double driveNm,double brakeNm,double dt) {
    bounded(dt,1.0/240,1.0/30);bounded(d.radius,.01,5);bounded(d.inertia,.001,1000);bounded(brakeNm,0,1e6);
    bounded(driveNm,-1e6,1e6);bounded(d.stiffness,0,1e7);bounded(d.damping,0,1e6);bounded(d.travel,0,5);
    bounded(d.muX,.001,5);bounded(d.muY,.001,5);bounded(w.omega,-10000,10000);
    double fx=0,fy=0,fz=0;Vec3 forward{1,0,0},side{0,1,0};
    if(c.hit&&(c.sweep||c.normal.z>.2)) {
        require(finite(c.normal)&&std::abs(length(c.normal)-1)<1e-5&&finite(c.forward),Error::InvalidRequest);
        forward=c.forward-c.normal*dot(c.forward,c.normal);require(length(forward)>.1,Error::InvalidRequest);forward=forward/length(forward);
        side=cross(c.normal,forward);
        auto hub=c.sweep?c.distance:c.distance-d.radius/c.normal.z;
        auto x=std::clamp(d.restLength-hub,0.0,d.travel);
        auto rate=std::clamp((x-w.compression)/dt,-5.0,5.0);w.compression=x;
        fz=std::clamp(d.stiffness*x+d.damping*rate,0.0,d.maxForce);
        auto r=d.radius*(w.punctured?.8:1),mu=w.punctured?.3:1;
        w.slipRatio=(r*w.omega-c.forwardSpeed)/std::max(.5,std::abs(c.forwardSpeed));
        w.slipAngle=std::atan2(c.sideSpeed,std::max(.5,std::abs(c.forwardSpeed)));
        if(std::abs(c.forwardSpeed)<.5&&std::abs(r*w.omega)<.5) {
            auto supported=fz/(9.80665*std::max(.2,c.normal.z));
            auto hold=-c.forwardSpeed*supported/dt+supported*9.80665*forward.z;
            fx=driveNm/r-std::clamp(driveNm/r-hold,-brakeNm/r,brakeNm/r);
            fy=-c.sideSpeed*supported/dt+supported*9.80665*side.z;
        } else {fx=d.longitudinal*w.slipRatio;fy=-d.lateral*w.slipAngle;}
        if(fz>1e-6) {auto scale=std::max(1.0,std::hypot(fx/(mu*d.muX*fz),fy/(mu*d.muY*fz)));fx/=scale;fy/=scale;}
        else fx=fy=0;
    } else {w.compression=0;w.slipRatio=w.slipAngle=0;}
    auto resistance=d.radius*fx+(w.omega==0?0:std::copysign(d.rolling*fz*d.radius,w.omega));
    auto next=w.omega+(driveNm-resistance)*dt/d.inertia;
    auto reduction=brakeNm*dt/d.inertia;w.omega=std::copysign(std::max(0.0,std::abs(next)-reduction),next);
    return {c.normal*fz+forward*fx+side*fy,d.anchor-Vec3{0,0,d.restLength-w.compression},fz};
}
}
