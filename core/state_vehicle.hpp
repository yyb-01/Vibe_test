#pragma once
#include "state_survival.hpp"
#include "vehicle.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,MassPart>
void state_fields(A& a,V& v){a(v.item,v.massKg,v.com,v.inertia,v.rotation);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Wheel>
void state_fields(A& a,V& v){a(v.omega,v.steer,v.compression,v.slipRatio,v.slipAngle,v.temperatureK,v.wear,v.punctured,v.attached);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Vehicle>
void state_fields(A& a,V& v){
    a(v.entity,v.driver,v.revision,v.assemblyRevision,v.tick,v.inputSeq,v.physicsRevision,v.position,v.velocity,v.omega,v.rotation,
      v.engineRpm,v.clutch,v.steer,v.fuelResidual,v.batteryResidual,v.fuelUl,v.batteryMilliJ,v.gear,v.drivenMask,v.running,v.torquePath);
    a.sequence(v.parts,64);a.sequence(v.wheels,6);
}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,WeaponRuntime>
void state_fields(A& a,V& v){a(v.item,v.owner,v.selectedMagazine,v.oldMagazine,v.netId,v.inputSeq,v.fireSeq,v.generation,
    v.revision,v.assemblyRevision,v.nextPhaseTick,v.lastFireTick,v.shotCounter,v.lastEffectiveQ16,v.phase,v.heatK,v.fouling,v.recoilPitch,v.recoilYaw,v.trigger);}
}
