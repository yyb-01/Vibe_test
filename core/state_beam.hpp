#pragma once
#include "state_wire.hpp"
#include "beam.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,ballistics::Resistance>
void state_fields(A& a,V& v){a(v.entryUj,v.resistanceUjPerUm,v.minPathUm,v.maxPathUm);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,BeamTarget>
void state_fields(A& a,V& v){a(v.entity,v.armor,v.epoch,v.kind,v.region,v.contact,v.vital,v.entering,v.material,v.u,v.v);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,BeamSlice>
void state_fields(A& a,V& v){a(v.entry,v.exit);a.sequence(v.active,16);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,BeamMotion>
void state_fields(A& a,V& v){a(v.entry,v.exit,v.startVelocity,v.endVelocity,v.pathUm,v.duration,v.elapsed,v.entryUj,v.endUj,v.absorbedUj,v.distributed,v.vitalEmitted);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,BeamTransit>
void state_fields(A& a,V& v){a.sequence(v.slices,32);a(v.index);a.optional(v.motion);}
}
