#pragma once
#include "state_survival.hpp"
#include "crafting.hpp"
#include "power.hpp"
namespace astra {
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,CraftJob>
void state_fields(A& a,V& v){a(v.entity,v.request,v.station,v.owner,v.escrow,v.source,v.revision,v.progressUs,v.energyUj,v.seed,v.recipe,v.version,v.batch,v.stage,v.phase);
    a.sequence(v.inputs,32);a.sequence(v.tools,8);a.sequence(v.outputs,3200);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Station>
void state_fields(A& a,V& v){a(v.entity,v.item,v.output,v.wreck,v.powerNode,v.owner,v.revision,v.capabilities,v.position,v.destroyed);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Crafting>
void state_fields(A& a,V& v){a.dictionary(v.jobs,1024);a.dictionary(v.stations,256);a.dictionary(v.toolLeases,8192);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,PowerNode>
void state_fields(A& a,V& v){a(v.entity,v.position,v.generateW,v.demandW,v.chargeW,v.dischargeW,v.batteryUj,v.capacityUj,v.fuelUj,v.chargeEfficiency,v.dischargeEfficiency,v.priority,v.partial,v.renewable);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,Cable>
void state_fields(A& a,V& v){a(v.a,v.b,v.maxLengthM);}
template<class A,class V> requires std::is_same_v<std::remove_cv_t<V>,PowerGrid>
void state_fields(A& a,V& v){a.dictionary(v.nodes,10000);a.sequence(v.cables,20000);}
}
