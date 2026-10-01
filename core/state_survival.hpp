#pragma once
#include "state_wire.hpp"
#include "survival.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Vec3>
void state_fields(A& a,V& v){a(v.x,v.y,v.z);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Wound>
void state_fields(A& a,V& v){a(v.event,v.region,v.arterialMlS,v.venousMlS,v.treatment,v.pain,v.fracture,v.depositedJ);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Pathogen>
void state_fields(A& a,V& v){a(v.dose,v.progress,v.onsetTick,v.infected);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Life>
void state_fields(A& a,V& v){
    a(v.entity,v.account,v.inventory,v.corpse,v.revision,v.tick,v.epoch,v.position,
      v.bloodMl,v.hydrationMl,v.energyKcal,v.staminaJ,v.coreK,v.skinK,v.fatigue,v.oxygenDebt,
      v.digestiveMl,v.digestiveKcal,v.heatExposure,v.coldExposure,v.health,v.status,v.cold,v.hot);
    a.sequence(v.wounds,64);a.dictionary(v.pathogens,16);
}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,ArmorMap>
void state_fields(A& a,V& v){a(v.integrity);}
}
